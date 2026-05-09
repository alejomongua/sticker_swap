class Sticker < ApplicationRecord
  has_many :inventory_items, dependent: :destroy
  has_many :offered_swap_offers,
           class_name: "SwapOffer",
           foreign_key: :offered_sticker_id,
           inverse_of: :offered_sticker,
           dependent: :restrict_with_exception
  has_many :requested_swap_offers,
           class_name: "SwapOffer",
           foreign_key: :requested_sticker_id,
           inverse_of: :requested_sticker,
           dependent: :restrict_with_exception

  normalizes :group_name, with: ->(value) { value.to_s.strip }
  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :prefix, with: ->(value) { value.to_s.strip.upcase }

  validates :number, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :prefix, uniqueness: { scope: :number }

  scope :catalog_order, -> { order(:group_name, :prefix, :number) }

  def code
    prefix.present? ? "#{prefix}#{number}" : format("%02d", number)
  end

  def display_name
    name.present? ? "#{code} · #{name}" : code
  end

  def sort_key
    [ group_name.to_s, prefix.to_s, number ]
  end

  def self.find_by_code(raw_code)
    prefix, number = split_code(raw_code)
    return if number.nil?

    find_by(prefix: prefix, number: number)
  end

  def self.split_code(raw_code)
    token = raw_code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    match = token.match(/\A([A-Z]*)(\d+)\z/)
    return [ nil, nil ] unless match

    [ match[1], match[2].to_i ]
  end
end
