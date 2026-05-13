require 'rails_helper'

RSpec.describe SwapOffer, type: :model do
  describe 'group boundaries' do
    it 'allows a trade between users who share the offer group' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      offered_sticker = create(:sticker, prefix: 'TSA', number: 10_001)
      offered_sticker_2 = create(:sticker, prefix: 'TSA', number: 10_002)
      requested_sticker = create(:sticker, prefix: 'TSB', number: 10_003)

      group.add_member!(receiver)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker_2)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)
      create(:inventory_item, user: receiver, sticker: offered_sticker_2, status: :missing)

      offer = described_class.new(
        group: group,
        sender: sender,
        receiver: receiver,
        offered_sticker_ids: [ offered_sticker.id, offered_sticker_2.id ],
        requested_sticker_ids: [ requested_sticker.id ],
        status: :pending
      )

      expect(offer).to be_valid
    end

    it 'rejects a trade when the receiver is outside the offer group' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      create(:group, admin_user: receiver)
      offered_sticker = create(:sticker, prefix: 'TSC', number: 10_004)
      requested_sticker = create(:sticker, prefix: 'TSD', number: 10_005)

      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      offer = described_class.new(
        group: group,
        sender: sender,
        receiver: receiver,
        offered_sticker_ids: [ offered_sticker.id ],
        requested_sticker_ids: [ requested_sticker.id ],
        status: :pending
      )

      expect(offer).not_to be_valid
      expect(offer.errors[:base]).to include('La propuesta solo puede involucrar miembros del grupo activo.')
    end
  end

  describe 'code parsing' do
    it 'parses code lists into sticker ids' do
      sender = create(:user, create_default_group: false)
      receiver = create(:user, create_default_group: false)
      group = create(:group, admin_user: sender)
      offered_sticker = create(:sticker, prefix: 'TSE', number: 10_006)
      requested_sticker = create(:sticker, prefix: 'TSF', number: 10_007)

      group.add_member!(receiver)
      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      offer = described_class.new(group: group, sender: sender, receiver: receiver, status: :pending)
      offer.offered_codes_text = offered_sticker.code
      offer.requested_codes_text = requested_sticker.code

      expect(offer).to be_valid
      expect(offer.offered_sticker_ids).to eq([ offered_sticker.id ])
      expect(offer.requested_sticker_ids).to eq([ requested_sticker.id ])
    end
  end

  describe '#accept!' do
    it 'accepts the offer and removes the exchanged inventory records' do
      offered_sticker = create(:sticker, prefix: 'TSG', number: 10_008)
      offered_sticker_2 = create(:sticker, prefix: 'TSG', number: 10_009)
      requested_sticker = create(:sticker, prefix: 'TSH', number: 10_010)
      requested_sticker_2 = create(:sticker, prefix: 'TSH', number: 10_011)
      offer = create(:swap_offer, offered_stickers: [ offered_sticker, offered_sticker_2 ], requested_stickers: [ requested_sticker, requested_sticker_2 ])

      offer.accept!

      expect(offer.reload).to be_accepted
      expect(offer.sender.inventory_items.exists?(sticker: offered_sticker)).to be(false)
      expect(offer.sender.inventory_items.exists?(sticker: offered_sticker_2)).to be(false)
      expect(offer.sender.inventory_items.exists?(sticker: requested_sticker)).to be(false)
      expect(offer.sender.inventory_items.exists?(sticker: requested_sticker_2)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: offered_sticker)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: offered_sticker_2)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: requested_sticker)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: requested_sticker_2)).to be(false)
    end

    it 'decrements repeated quantities instead of removing the row when extra copies remain' do
      offered_sticker = create(:sticker, prefix: 'TSI', number: 10_012)
      requested_sticker = create(:sticker, prefix: 'TSJ', number: 10_013)
      offer = create(:swap_offer, offered_stickers: [ offered_sticker ], requested_stickers: [ requested_sticker ])
      offer.sender.inventory_items.find_by!(sticker: offered_sticker).update!(quantity: 3)
      offer.receiver.inventory_items.find_by!(sticker: requested_sticker).update!(quantity: 2)

      offer.accept!

      expect(offer.sender.inventory_items.find_by!(sticker: offered_sticker).quantity).to eq(2)
      expect(offer.receiver.inventory_items.find_by!(sticker: requested_sticker).quantity).to eq(1)
      expect(offer.sender.inventory_items.exists?(sticker: requested_sticker)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: offered_sticker)).to be(false)
    end
  end

  describe 'notifications' do
    it 'enqueues an email when the receiver wants notifications' do
      perform_enqueued_jobs do
        expect { create(:swap_offer) }.to change(ActionMailer::Base.deliveries, :count).by(1)
      end
    end

    it 'does not enqueue an email when the receiver disabled notifications' do
      sender = create(:user)
      receiver = create(:user, receive_offer_notifications: false)
      offered_sticker = create(:sticker, prefix: 'TSK', number: 10_014)
      requested_sticker = create(:sticker, prefix: 'TSL', number: 10_015)

      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      expect { create(:swap_offer, sender: sender, receiver: receiver, offered_stickers: [ offered_sticker ], requested_stickers: [ requested_sticker ]) }
        .not_to have_enqueued_job
    end
  end
end
