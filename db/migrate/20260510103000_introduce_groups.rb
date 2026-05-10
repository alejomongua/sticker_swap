require "securerandom"

class IntroduceGroups < ActiveRecord::Migration[8.1]
  class MigrationGroup < ApplicationRecord
    self.table_name = "groups"
  end

  class MigrationGroupMembership < ApplicationRecord
    self.table_name = "group_memberships"
  end

  class MigrationSwapOffer < ApplicationRecord
    self.table_name = "swap_offers"
  end

  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    create_table :groups do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :invitation_code, null: false
      t.string :name, null: false
      t.boolean :registration_open, default: true, null: false
      t.timestamps
    end

    add_index :groups, :invitation_code, unique: true

    create_table :group_memberships do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :group_memberships, %i[group_id user_id], unique: true

    add_reference :users, :active_group, foreign_key: { to_table: :groups }
    add_reference :swap_offers, :group, foreign_key: true

    backfill_existing_users_and_offers!
  end

  def down
    remove_reference :swap_offers, :group, foreign_key: true
    remove_reference :users, :active_group, foreign_key: { to_table: :groups }

    drop_table :group_memberships
    drop_table :groups
  end

  private
    def backfill_existing_users_and_offers!
      return if MigrationUser.count.zero?

      admin_user = MigrationUser.order(:id).first
      legacy_group = MigrationGroup.create!(
        admin_user_id: admin_user.id,
        invitation_code: legacy_invitation_code,
        name: "Grupo principal",
        registration_open: true
      )

      MigrationUser.find_each do |user|
        MigrationGroupMembership.create!(group_id: legacy_group.id, user_id: user.id)
        user.update_columns(active_group_id: legacy_group.id)
      end

      MigrationSwapOffer.where(group_id: nil).update_all(group_id: legacy_group.id)
    end

    def legacy_invitation_code
      base_code = normalize_invitation_code(ENV.fetch("REGISTRATION_CODE", "STICKERSWAP2026"))
      return base_code unless MigrationGroup.exists?(invitation_code: base_code)

      loop do
        candidate = "GRUPO#{SecureRandom.alphanumeric(6).upcase}"
        return candidate unless MigrationGroup.exists?(invitation_code: candidate)
      end
    end

    def normalize_invitation_code(raw_code)
      raw_code.to_s.upcase.gsub(/[^A-Z0-9]/, "").presence || "STICKERSWAP2026"
    end
end
