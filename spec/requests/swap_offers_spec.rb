require 'rails_helper'

RSpec.describe 'SwapOffers', type: :request do
  describe 'POST /intercambios' do
    it 'creates a trade proposal when both users belong to the active group' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      offered_sticker = create(:sticker, prefix: 'TSM', number: 10_016)
      offered_sticker_2 = create(:sticker, prefix: 'TSM', number: 10_017)
      requested_sticker = create(:sticker, prefix: 'TSN', number: 10_018)

      group.add_member!(receiver)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker_2)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)
      create(:inventory_item, user: receiver, sticker: offered_sticker_2, status: :missing)

      sign_in_as(sender)

      expect do
        post swap_offers_path, params: {
          swap_offer: {
            receiver_id: receiver.id,
            offered_codes_text: "#{offered_sticker.code}, #{offered_sticker_2.code}",
            requested_codes_text: requested_sticker.code
          }
        }
      end.to change(SwapOffer, :count).by(1)

      offer = SwapOffer.order(:id).last

      expect(response).to redirect_to(matches_path)
      expect(flash[:notice]).to eq('La propuesta se envió correctamente.')
      expect(offer.group).to eq(group)
      expect(offer.sender).to eq(sender)
      expect(offer.receiver).to eq(receiver)
      expect(offer.offered_sticker_ids).to match_array([ offered_sticker.id, offered_sticker_2.id ])
      expect(offer.requested_sticker_ids).to eq([ requested_sticker.id ])
    end

    it 'rejects a trade proposal with users outside the active group' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      create(:group, admin_user: receiver)
      offered_sticker = create(:sticker, prefix: 'TSO', number: 10_019)
      requested_sticker = create(:sticker, prefix: 'TSP', number: 10_020)

      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      sign_in_as(sender)

      expect do
        post swap_offers_path, params: {
          swap_offer: {
            receiver_id: receiver.id,
            offered_codes_text: offered_sticker.code,
            requested_codes_text: requested_sticker.code
          }
        }
      end.not_to change(SwapOffer, :count)

      expect(response).to redirect_to(matches_path)
      expect(flash[:alert]).to include('La propuesta solo puede involucrar miembros del grupo activo.')
    end

    it 'lets the receiver counter an offer and flips the participants' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      offered_sticker = create(:sticker, prefix: 'TSQ', number: 10_021)
      requested_sticker = create(:sticker, prefix: 'TSR', number: 10_022)
      requested_sticker_2 = create(:sticker, prefix: 'TSR', number: 10_023)

      group.add_member!(receiver)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, user: sender, sticker: requested_sticker_2, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker_2)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      original_offer = create(
        :swap_offer,
        group: group,
        sender: sender,
        receiver: receiver,
        offered_stickers: [ offered_sticker ],
        requested_stickers: [ requested_sticker ]
      )

      sign_in_as(receiver)

      expect do
        post swap_offers_path, params: {
          swap_offer: {
            countered_from_id: original_offer.id,
            offered_codes_text: requested_sticker_2.code,
            requested_codes_text: offered_sticker.code
          }
        }
      end.to change(SwapOffer, :count).by(1)

      counter_offer = SwapOffer.order(:id).last

      expect(response).to redirect_to(swap_offers_path)
      expect(flash[:notice]).to eq('La contraoferta se envió correctamente.')
      expect(original_offer.reload).to be_countered
      expect(counter_offer.sender).to eq(receiver)
      expect(counter_offer.receiver).to eq(sender)
      expect(counter_offer.countered_from).to eq(original_offer)
      expect(counter_offer.offered_sticker_ids).to eq([ requested_sticker_2.id ])
      expect(counter_offer.requested_sticker_ids).to eq([ offered_sticker.id ])
    end
  end
end
