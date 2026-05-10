class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_id }

  before_destroy :prevent_removing_admin
  after_commit :sync_user_active_group!, on: :create
  after_destroy_commit :remove_group_offers_and_sync_user!

  private
    def prevent_removing_admin
      return unless user_id == group.admin_user_id

      errors.add(:base, "No puedes eliminar al administrador del grupo.")
      throw :abort
    end

    def remove_group_offers_and_sync_user!
      group.swap_offers.where(sender_id: user_id).or(group.swap_offers.where(receiver_id: user_id)).delete_all
      sync_user_active_group!
    end

    def sync_user_active_group!
      user.sync_active_group!
    end
end
