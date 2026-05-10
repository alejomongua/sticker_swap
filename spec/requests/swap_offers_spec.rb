require 'rails_helper'

RSpec.describe 'SwapOffers', type: :request do
  describe 'POST /intercambios' do
    it 'creates a trade proposal when both users belong to the active group' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      offered_sticker = create(:sticker, prefix: 'ARG', number: 1)
      requested_sticker = create(:sticker, prefix: 'BRA', number: 2)

      group.add_member!(receiver)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      sign_in_as(sender)

      expect do
        post swap_offers_path, params: {
          swap_offer: {
            receiver_id: receiver.id,
            offered_sticker_id: offered_sticker.id,
            requested_sticker_id: requested_sticker.id
          }
        }
      end.to change(SwapOffer, :count).by(1)

      offer = SwapOffer.order(:id).last

      expect(response).to redirect_to(matches_path)
      expect(flash[:notice]).to eq('La propuesta se envió correctamente.')
      expect(offer.group).to eq(group)
      expect(offer.sender).to eq(sender)
      expect(offer.receiver).to eq(receiver)
    end

    it 'rejects a trade proposal with users outside the active group' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      create(:group, admin_user: receiver)
      offered_sticker = create(:sticker, prefix: 'ARG', number: 1)
      requested_sticker = create(:sticker, prefix: 'BRA', number: 2)

      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      sign_in_as(sender)

      expect do
        post swap_offers_path, params: {
          swap_offer: {
            receiver_id: receiver.id,
            offered_sticker_id: offered_sticker.id,
            requested_sticker_id: requested_sticker.id
          }
        }
      end.not_to change(SwapOffer, :count)

      expect(response).to redirect_to(matches_path)
      expect(flash[:alert]).to include('La propuesta solo puede involucrar miembros del grupo activo.')
    end
  end
end
