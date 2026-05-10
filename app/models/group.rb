require "securerandom"

class Group < ApplicationRecord
  INVITATION_CODE_LENGTH = 10

  belongs_to :admin_user, class_name: "User", inverse_of: :admin_groups
  has_many :group_memberships, dependent: :destroy
  has_many :swap_offers, dependent: :destroy
  has_many :users, through: :group_memberships

  normalizes :invitation_code, with: ->(value) { normalize_invitation_code(value) }
  normalizes :name, with: ->(value) { value.to_s.strip }

  before_validation :assign_invitation_code, on: :create
  after_create :ensure_admin_membership!

  validates :invitation_code,
            format: { with: /\A[A-Z0-9]+\z/, message: "solo puede contener letras y números" },
            presence: true,
            uniqueness: { case_sensitive: false }
  validates :name, length: { maximum: 80 }, presence: true
  validates :registration_open, inclusion: { in: [ true, false ] }

  def self.find_by_invitation_code(raw_code)
    normalized_code = normalize_invitation_code(raw_code)
    return if normalized_code.blank?

    find_by(invitation_code: normalized_code)
  end

  def self.normalize_invitation_code(raw_code)
    raw_code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def add_member!(user)
    group_memberships.find_or_create_by!(user: user).tap do
      user.update_column(:active_group_id, id) if user.active_group_id != id
    end
  end

  def regenerate_invitation_code!
    update!(invitation_code: generate_unique_invitation_code)
  end

  private
    def assign_invitation_code
      self.invitation_code = generate_unique_invitation_code if invitation_code.blank?
    end

    def ensure_admin_membership!
      group_memberships.find_or_create_by!(user: admin_user)
    end

    def generate_unique_invitation_code
      loop do
        candidate = SecureRandom.alphanumeric(INVITATION_CODE_LENGTH).upcase
        return candidate unless self.class.where.not(id: id).exists?(invitation_code: candidate)
      end
    end
end
