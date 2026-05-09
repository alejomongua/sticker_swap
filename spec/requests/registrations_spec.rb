require 'rails_helper'

RSpec.describe 'Registrations', type: :request do
  around do |example|
    previous_code = ENV["REGISTRATION_CODE"]
    ENV["REGISTRATION_CODE"] = "STICKER2026"

    example.run
  ensure
    ENV["REGISTRATION_CODE"] = previous_code
  end

  describe 'POST /registro' do
    it 'creates users while the configured invitation code stays the same' do
      expect do
        post registration_path, params: {
          user: {
            username: 'alejo',
            email: 'alejo@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            invitation_code: 'sticker-2026',
            receive_offer_notifications: '1'
          }
        }

        post registration_path, params: {
          user: {
            username: 'pepe',
            email: 'pepe@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            invitation_code: 'STICKER2026',
            receive_offer_notifications: '1'
          }
        }
      end.to change(User, :count).by(2)

      expect(response).to redirect_to(root_path)
    end

    it 'rejects the registration when the invitation code is invalid' do
      post registration_path, params: {
        user: {
          username: 'alejo',
          email: 'alejo@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          invitation_code: 'NOEXISTE',
          receive_offer_notifications: '1'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('El código de invitación no es válido o ya fue usado.')
    end
  end
end
