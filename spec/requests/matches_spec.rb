require 'rails_helper'

RSpec.describe 'Matches', type: :request do
  describe 'GET /mercado' do
    it 'only shows matching users from the active group' do
      current_user = create(:user, create_default_group: false)
      teammate = create(:user, create_default_group: false)
      outsider = create(:user, create_default_group: false)
      group = create(:group, admin_user: current_user)
      offered_sticker = create(:sticker, prefix: 'ZZMO', number: 71_001, name: 'Argentina')
      requested_sticker = create(:sticker, prefix: 'ZZMP', number: 71_002, name: 'Brasil')

      group.add_member!(teammate)

      create(:inventory_item, :duplicate, user: current_user, sticker: offered_sticker)
      create(:inventory_item, user: current_user, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: teammate, sticker: requested_sticker)
      create(:inventory_item, user: teammate, sticker: offered_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: outsider, sticker: requested_sticker)
      create(:inventory_item, user: outsider, sticker: offered_sticker, status: :missing)

      sign_in_as(current_user)

      get matches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(teammate.username)
      expect(response.body).not_to include(outsider.username)
    end
  end
end
