class SwapOffer < ApplicationRecord
  belongs_to :group
  belongs_to :receiver, class_name: "User", inverse_of: :received_swap_offers
  belongs_to :sender, class_name: "User", inverse_of: :sent_swap_offers
  belongs_to :countered_from, class_name: "SwapOffer", optional: true, inverse_of: :counter_offer

  has_one :counter_offer,
          class_name: "SwapOffer",
          foreign_key: :countered_from_id,
          inverse_of: :countered_from,
          dependent: :nullify

  enum :status, { pending: 0, accepted: 1, declined: 2, countered: 3 }

  attr_writer :offered_codes_text, :requested_codes_text

  validates :status, presence: true
  validate :participants_must_belong_to_group
  validate :participants_must_be_different
  validate :sticker_lists_must_be_present
  validate :sticker_lists_must_not_overlap
  validate :parsed_codes_must_exist
  validate :countered_offer_must_match_trade, on: :create
  validate :inventory_must_match, on: :create
  validate :no_duplicate_pending_offer, on: :create

  before_validation :resolve_sticker_codes_inputs
  before_validation :normalize_sticker_ids

  after_create_commit :notify_receiver, if: -> { receiver.receive_offer_notifications? }

  scope :latest_first, -> { order(created_at: :desc) }

  def accept!
    SwapOfferAcceptance.new(self).call
  end

  def decline!
    raise SwapOfferAcceptance::InvalidState, "La propuesta ya fue respondida." unless pending?

    update!(status: :declined, responded_at: Time.current)
  end

  def counter!
    raise SwapOfferAcceptance::InvalidState, "La propuesta ya fue respondida." unless pending?

    update!(status: :countered, responded_at: Time.current)
  end

  def offered_codes_text
    return @offered_codes_text if instance_variable_defined?(:@offered_codes_text)

    sticker_codes_text(offered_sticker_ids)
  end

  def requested_codes_text
    return @requested_codes_text if instance_variable_defined?(:@requested_codes_text)

    sticker_codes_text(requested_sticker_ids)
  end

  def offered_stickers
    stickers_for_ids(offered_sticker_ids)
  end

  def requested_stickers
    stickers_for_ids(requested_sticker_ids)
  end

  def offered_stickers_summary
    sticker_summary(offered_sticker_ids)
  end

  def requested_stickers_summary
    sticker_summary(requested_sticker_ids)
  end

  def status_label
    case status
    when "accepted" then "Aceptada"
    when "declined" then "Rechazada"
    when "countered" then "Contraofertada"
    else "Pendiente"
    end
  end

  private
    def resolve_sticker_codes_inputs
      resolve_codes_input(:offered) if instance_variable_defined?(:@offered_codes_text)
      resolve_codes_input(:requested) if instance_variable_defined?(:@requested_codes_text)
    end

    def normalize_sticker_ids
      self.offered_sticker_ids = normalize_ids(offered_sticker_ids)
      self.requested_sticker_ids = normalize_ids(requested_sticker_ids)
    end

    def inventory_must_match
      return if sender.blank? || receiver.blank? || offered_sticker_ids.blank? || requested_sticker_ids.blank?

      validate_inventory_side(
        user: sender,
        sticker_ids: offered_sticker_ids,
        status: :duplicate,
        message: "Ya no tienes estas figuras para ofrecer"
      )
      validate_inventory_side(
        user: receiver,
        sticker_ids: offered_sticker_ids,
        status: :missing,
        message: "La otra persona ya no necesita estas figuras"
      )
      validate_inventory_side(
        user: receiver,
        sticker_ids: requested_sticker_ids,
        status: :duplicate,
        message: "La otra persona ya no tiene estas figuras disponibles"
      )
      validate_inventory_side(
        user: sender,
        sticker_ids: requested_sticker_ids,
        status: :missing,
        message: "Estas figuras ya no aparecen como faltantes en tu inventario"
      )
    end

    def no_duplicate_pending_offer
      return if group_id.blank? || sender_id.blank? || receiver_id.blank? || offered_sticker_ids.blank? || requested_sticker_ids.blank?

      duplicate_offer = self.class.pending.where(
        group_id: group_id,
        sender_id: sender_id,
        receiver_id: receiver_id,
        offered_sticker_ids: offered_sticker_ids,
        requested_sticker_ids: requested_sticker_ids
      )
      duplicate_offer = duplicate_offer.where.not(id: id) if persisted?

      errors.add(:base, "Ya existe una propuesta pendiente idéntica.") if duplicate_offer.exists?
    end

    def notify_receiver
      SwapOffersMailer.created(self).deliver_later
    end

    def participants_must_belong_to_group
      return if group.blank? || sender_id.blank? || receiver_id.blank?

      member_ids = group.group_memberships.where(user_id: [ sender_id, receiver_id ]).distinct.count
      return if member_ids == 2

      errors.add(:base, "La propuesta solo puede involucrar miembros del grupo activo.")
    end

    def participants_must_be_different
      return if sender_id.blank? || receiver_id.blank? || sender_id != receiver_id

      errors.add(:receiver, "debe ser otra persona")
    end

    def sticker_lists_must_be_present
      errors.add(:base, "Debes elegir al menos una figura para ofrecer.") if offered_sticker_ids.blank?
      errors.add(:base, "Debes elegir al menos una figura para solicitar.") if requested_sticker_ids.blank?
    end

    def sticker_lists_must_not_overlap
      return if (offered_sticker_ids & requested_sticker_ids).empty?

      errors.add(:base, "No puedes ofrecer y solicitar la misma figura en un mismo trato.")
    end

    def parsed_codes_must_exist
      errors.add(:base, "No encontramos estas figuras para ofrecer: #{formatted_codes(@invalid_offered_codes)}.") if @invalid_offered_codes.present?
      errors.add(:base, "No encontramos estas figuras para solicitar: #{formatted_codes(@invalid_requested_codes)}.") if @invalid_requested_codes.present?
    end

    def countered_offer_must_match_trade
      return if countered_from.blank?

      unless countered_from.pending?
        errors.add(:base, "La propuesta original ya fue respondida.")
        return
      end

      return if countered_from.group_id == group_id && countered_from.receiver_id == sender_id && countered_from.sender_id == receiver_id

      errors.add(:base, "Solo puedes modificar una propuesta pendiente que te hayan enviado.")
    end

    def validate_inventory_side(user:, sticker_ids:, status:, message:)
      unavailable_ids = sticker_ids.reject do |sticker_id|
        user.inventory_items.exists?(sticker_id: sticker_id, status: status)
      end
      return if unavailable_ids.empty?

      errors.add(:base, "#{message}: #{sticker_summary(unavailable_ids)}.")
    end

    def resolve_codes_input(side)
      raw_text = instance_variable_get("@#{side}_codes_text")
      parsed_codes = parse_codes_list(raw_text)
      invalid_codes = []
      sticker_ids = parsed_codes.filter_map do |code|
        sticker = Sticker.find_by_code(code)

        if sticker
          sticker.id
        else
          invalid_codes << code
          nil
        end
      end

      instance_variable_set("@invalid_#{side}_codes", invalid_codes.uniq)
      public_send("#{side}_sticker_ids=", sticker_ids)
    end

    def normalize_ids(ids)
      Array(ids).filter_map do |value|
        Integer(value, exception: false)
      end.uniq
    end

    def parse_codes_list(raw_text)
      raw_text.to_s.split(/[^A-Za-z0-9]+/).filter_map do |token|
        normalized = token.to_s.upcase.strip
        normalized.presence
      end
    end

    def stickers_for_ids(ids)
      stickers_by_id = Sticker.where(id: ids).index_by(&:id)
      ids.filter_map { |sticker_id| stickers_by_id[sticker_id] }
    end

    def sticker_codes_text(ids)
      stickers_for_ids(ids).map(&:code).join(", ")
    end

    def sticker_summary(ids)
      stickers_for_ids(ids).map(&:display_name).join(", ")
    end

    def formatted_codes(codes)
      Array(codes).join(", ")
    end
end
