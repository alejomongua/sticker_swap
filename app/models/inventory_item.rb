class InventoryItem < ApplicationRecord
  belongs_to :user
  belongs_to :sticker

  enum :status, { missing: 0, duplicate: 1 }

  before_validation :normalize_quantity

  validates :status, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :sticker_id, uniqueness: { scope: :user_id, message: "ya está cargada en tu inventario" }
  validate :quantity_must_match_status

  delegate :code, :display_name, to: :sticker

  scope :ordered, -> { includes(:sticker).references(:stickers).merge(Sticker.catalog_order) }

  def consume_one!
    return destroy! if missing? || quantity == 1

    decrement!(:quantity)
  end

  private
    def normalize_quantity
      self.quantity = 1 if missing?
    end

    def quantity_must_match_status
      return unless missing? && quantity.present? && quantity != 1

      errors.add(:quantity, "debe ser 1 para faltantes")
    end
end
