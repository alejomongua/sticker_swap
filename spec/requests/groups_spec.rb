require 'rails_helper'

RSpec.describe 'Groups', type: :request do
  describe 'POST /grupos/unirse' do
    it 'adds the user to another group and switches the active group' do
      user = create(:user)
      target_group = create(:group, admin_user: create(:user, create_default_group: false), invitation_code: 'OFICINA2026')

      sign_in_as(user)

      post join_groups_path, params: { group: { invitation_code: 'oficina-2026' } }

      expect(response).to redirect_to(groups_path)
      expect(user.reload.active_group).to eq(target_group)
      expect(target_group.users).to include(user)
    end
  end

  describe 'admin actions' do
    it 'lets the admin close registration, regenerate the invitation code, and remove members' do
      admin = create(:user, create_default_group: false)
      member = create(:user, create_default_group: false)
      group = create(:group, admin_user: admin, invitation_code: 'OFICINA2026')

      group.add_member!(member)
      sign_in_as(admin)

      patch group_path(group), params: { group: { registration_open: '0' } }

      expect(response).to redirect_to(groups_path)
      expect(group.reload).not_to be_registration_open

      old_code = group.invitation_code

      post regenerate_invitation_code_group_path(group)

      expect(response).to redirect_to(groups_path)
      expect(group.reload.invitation_code).not_to eq(old_code)

      membership = group.group_memberships.find_by!(user: member)

      expect do
        delete group_group_membership_path(group, membership)
      end.to change { group.reload.users.count }.by(-1)
    end

    it 'rejects member management from non-admin users' do
      admin = create(:user, create_default_group: false)
      member = create(:user, create_default_group: false)
      other_member = create(:user, create_default_group: false)
      group = create(:group, admin_user: admin)

      group.add_member!(member)
      group.add_member!(other_member)
      sign_in_as(member)

      delete group_group_membership_path(group, group.group_memberships.find_by!(user: other_member))

      expect(response).to redirect_to(groups_path)
      expect(flash[:alert]).to include('Solo el administrador puede gestionar este grupo.')
      expect(group.reload.users).to include(other_member)
    end
  end
end
