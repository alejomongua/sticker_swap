require 'rails_helper'

RSpec.describe SwapOffer, type: :model do
  describe 'group boundaries' do
    it 'allows a trade between users who share the offer group' do
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

      offer = described_class.new(
        group: group,
        sender: sender,
        receiver: receiver,
        offered_sticker: offered_sticker,
        requested_sticker: requested_sticker,
        status: :pending
      )

      expect(offer).to be_valid
    end

    it 'rejects a trade when the receiver is outside the offer group' do
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

      offer = described_class.new(
        group: group,
        sender: sender,
        receiver: receiver,
        offered_sticker: offered_sticker,
        requested_sticker: requested_sticker,
        status: :pending
      )

      expect(offer).not_to be_valid
      expect(offer.errors[:base]).to include('La propuesta solo puede involucrar miembros del grupo activo.')
    end
  end

  describe '#accept!' do
    it 'accepts the offer and removes the exchanged inventory records' do
      offer = create(:swap_offer)

      offer.accept!

      expect(offer.reload).to be_accepted
      expect(offer.sender.inventory_items.exists?(sticker: offer.offered_sticker)).to be(false)
      expect(offer.sender.inventory_items.exists?(sticker: offer.requested_sticker)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: offer.offered_sticker)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: offer.requested_sticker)).to be(false)
    end

    it 'decrements repeated quantities instead of removing the row when extra copies remain' do
      offer = create(:swap_offer)
      offer.sender.inventory_items.find_by!(sticker: offer.offered_sticker).update!(quantity: 3)
      offer.receiver.inventory_items.find_by!(sticker: offer.requested_sticker).update!(quantity: 2)

      offer.accept!

      expect(offer.sender.inventory_items.find_by!(sticker: offer.offered_sticker).quantity).to eq(2)
      expect(offer.receiver.inventory_items.find_by!(sticker: offer.requested_sticker).quantity).to eq(1)
      expect(offer.sender.inventory_items.exists?(sticker: offer.requested_sticker)).to be(false)
      expect(offer.receiver.inventory_items.exists?(sticker: offer.offered_sticker)).to be(false)
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
      offered_sticker = create(:sticker, prefix: 'ARG', number: 1)
      requested_sticker = create(:sticker, prefix: 'BRA', number: 2)

      create(:inventory_item, :duplicate, user: sender, sticker: offered_sticker)
      create(:inventory_item, user: sender, sticker: requested_sticker, status: :missing)
      create(:inventory_item, :duplicate, user: receiver, sticker: requested_sticker)
      create(:inventory_item, user: receiver, sticker: offered_sticker, status: :missing)

      expect { create(:swap_offer, sender: sender, receiver: receiver, offered_sticker: offered_sticker, requested_sticker: requested_sticker) }
        .not_to have_enqueued_job
    end
  end
end
