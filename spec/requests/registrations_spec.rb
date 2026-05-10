require 'rails_helper'

RSpec.describe 'Registrations', type: :request do
  describe 'GET /registro' do
    it 'does not expose the offer notification preference in the signup form' do
      get new_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('receive_offer_notifications')
      expect(response.body).not_to include('Recibir notificaciones por correo')
    end
  end

  describe 'POST /registro' do
    it 'creates a user inside an existing group when the invitation code is valid' do
      group = create(:group, admin_user: create(:user, create_default_group: false), invitation_code: 'OFICINA2026')

      expect do
        post registration_path, params: {
          user: {
            username: 'alejo',
            email: 'alejo@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            registration_mode: 'join_group',
            invitation_code: 'oficina-2026'
          }
        }
      end.to change(User, :count).by(1)

      user = User.find_by!(email: 'alejo@example.com')
      expect(response).to redirect_to(root_path)
      expect(user.active_group).to eq(group)
      expect(group.users).to include(user)
      expect(user.receive_offer_notifications).to be(false)
    end

    it 'creates a new group and makes the registered user its administrator' do
      expect do
        post registration_path, params: {
          user: {
            username: 'alejo',
            email: 'alejo@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            registration_mode: 'create_group',
            group_name: 'Amigos de la oficina'
          }
        }
      end.to change(User, :count).by(1).and change(Group, :count).by(1)

      user = User.find_by!(email: 'alejo@example.com')
      group = user.admin_groups.first

      expect(response).to redirect_to(root_path)
      expect(group.name).to eq('Amigos de la oficina')
      expect(user.active_group).to eq(group)
      expect(group.users).to include(user)
      expect(user.receive_offer_notifications).to be(false)
    end

    it 'rejects the registration when the invitation code is invalid' do
      post registration_path, params: {
        user: {
          username: 'alejo',
          email: 'alejo@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          registration_mode: 'join_group',
          invitation_code: 'NOEXISTE'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('El código de invitación no es válido.')
    end

    it 'rejects the registration when the group disabled new members' do
      group = create(:group, admin_user: create(:user, create_default_group: false), registration_open: false)

      post registration_path, params: {
        user: {
          username: 'alejo',
          email: 'alejo@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          registration_mode: 'join_group',
          invitation_code: group.invitation_code
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Este grupo tiene el registro desactivado.')
    end
  end
end
