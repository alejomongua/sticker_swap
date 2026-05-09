class SwapOffer < ApplicationRecord
  belongs_to :offered_sticker, class_name: "Sticker", inverse_of: :offered_swap_offers
  belongs_to :receiver, class_name: "User", inverse_of: :received_swap_offers
  belongs_to :requested_sticker, class_name: "Sticker", inverse_of: :requested_swap_offers
  belongs_to :sender, class_name: "User", inverse_of: :sent_swap_offers

  enum :status, { pending: 0, accepted: 1, declined: 2 }

  validates :status, presence: true
  validate :participants_must_be_different
  validate :stickers_must_be_different
  validate :inventory_must_match, on: :create
  validate :no_duplicate_pending_offer, on: :create

  after_create_commit :notify_receiver, if: -> { receiver.receive_offer_notifications? }

  scope :latest_first, -> { order(created_at: :desc) }

  def accept!
    SwapOfferAcceptance.new(self).call
  end

  def decline!
    raise SwapOfferAcceptance::InvalidState, "La propuesta ya fue respondida." unless pending?

    update!(status: :declined, responded_at: Time.current)
  end

  def status_label
    case status
    when "accepted" then "Aceptada"
    when "declined" then "Rechazada"
    else "Pendiente"
    end
  end

  private
    def inventory_must_match
      return if sender.blank? || receiver.blank? || offered_sticker.blank? || requested_sticker.blank?

      unless sender.inventory_items.exists?(sticker: offered_sticker, status: :duplicate)
        errors.add(:base, "Ya no tienes la figura que intentas ofrecer.")
      end

      unless receiver.inventory_items.exists?(sticker: requested_sticker, status: :duplicate)
        errors.add(:base, "La otra persona ya no tiene la figura que quieres pedir.")
      end

      unless receiver.inventory_items.exists?(sticker: offered_sticker, status: :missing)
        errors.add(:base, "La otra persona ya no necesita la figura que intentas ofrecer.")
      end

      unless sender.inventory_items.exists?(sticker: requested_sticker, status: :missing)
        errors.add(:base, "Esa figura ya no figura como faltante en tu inventario.")
      end
    end

    def no_duplicate_pending_offer
      return if sender_id.blank? || receiver_id.blank? || offered_sticker_id.blank? || requested_sticker_id.blank?

      duplicate_offer = self.class.pending.where(
        sender_id: sender_id,
        receiver_id: receiver_id,
        offered_sticker_id: offered_sticker_id,
        requested_sticker_id: requested_sticker_id
      )

      errors.add(:base, "Ya existe una propuesta pendiente idéntica.") if duplicate_offer.exists?
    end

    def notify_receiver
      SwapOffersMailer.created(self).deliver_later
    end

    def participants_must_be_different
      return if sender_id.blank? || receiver_id.blank? || sender_id != receiver_id

      errors.add(:receiver, "debe ser otra persona")
    end

    def stickers_must_be_different
      return if offered_sticker_id.blank? || requested_sticker_id.blank? || offered_sticker_id != requested_sticker_id

      errors.add(:requested_sticker, "debe ser distinta a la figura ofrecida")
    end
end
