class User < ApplicationRecord
  has_secure_password
  has_many :inventory_items, dependent: :destroy
  has_many :received_swap_offers,
           class_name: "SwapOffer",
           foreign_key: :receiver_id,
           inverse_of: :receiver,
           dependent: :destroy
  has_many :sent_swap_offers,
           class_name: "SwapOffer",
           foreign_key: :sender_id,
           inverse_of: :sender,
           dependent: :destroy
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :username, with: ->(value) { value.to_s.strip }

  before_validation :disable_offer_notifications_on_create, on: :create

  validates :email,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "no es válido" },
            presence: true,
            uniqueness: true
  validates :password, length: { minimum: 8, message: "debe tener al menos 8 caracteres" }, if: -> { password.present? }
  validates :username, length: { maximum: 30 }, presence: true, uniqueness: { case_sensitive: false }

  def duplicate_items
    inventory_items.duplicate.includes(:sticker).ordered
  end

  def missing_items
    inventory_items.missing.includes(:sticker).ordered
  end

  def password_reset_token
    signed_id(expires_in: 30.minutes, purpose: :password_reset)
  end

  def self.find_by_password_reset_token!(token)
    find_signed!(token, purpose: :password_reset)
  end

  private
    def disable_offer_notifications_on_create
      self.receive_offer_notifications = false
    end
end
