class User < ApplicationRecord
  belongs_to :active_group, class_name: "Group", optional: true
  has_many :admin_groups,
           class_name: "Group",
           foreign_key: :admin_user_id,
           inverse_of: :admin_user
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
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
  validate :active_group_must_belong_to_user

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

  def admin_of?(group)
    admin_groups.exists?(id: group.id)
  end

  def member_of?(group)
    groups.exists?(id: group.id)
  end

  def sync_active_group!
    next_group_id = if active_group_id.present? && group_memberships.exists?(group_id: active_group_id)
      active_group_id
    else
      group_memberships.order(:created_at, :id).pick(:group_id)
    end

    update_column(:active_group_id, next_group_id)
  end

  private
    def active_group_must_belong_to_user
      return if active_group_id.blank? || group_memberships.exists?(group_id: active_group_id)

      errors.add(:active_group, "debe ser uno de tus grupos")
    end

    def disable_offer_notifications_on_create
      self.receive_offer_notifications = false
    end
end
