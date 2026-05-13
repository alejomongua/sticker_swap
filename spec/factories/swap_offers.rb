FactoryBot.define do
  factory :swap_offer do
    association :sender, factory: :user
    association :receiver, factory: :user
    status { :pending }

    transient do
      offered_stickers { [ create(:sticker) ] }
      requested_stickers { [ create(:sticker) ] }
    end

    after(:build) do |offer, evaluator|
      next unless offer.sender&.persisted? && offer.receiver&.persisted?

      shared_group = (offer.sender.groups.to_a & offer.receiver.groups.to_a).first

      unless shared_group
        shared_group = offer.sender.groups.first || create(:group, admin_user: offer.sender)
        shared_group.add_member!(offer.receiver)
      end

      offer.group ||= shared_group

      offer.offered_sticker_ids = evaluator.offered_stickers.map(&:id)
      offer.requested_sticker_ids = evaluator.requested_stickers.map(&:id)

      evaluator.offered_stickers.each do |sticker|
        offer.sender.inventory_items.find_or_create_by!(sticker: sticker) { |item| item.status = :duplicate }
        offer.receiver.inventory_items.find_or_create_by!(sticker: sticker) { |item| item.status = :missing }
      end

      evaluator.requested_stickers.each do |sticker|
        offer.sender.inventory_items.find_or_create_by!(sticker: sticker) { |item| item.status = :missing }
        offer.receiver.inventory_items.find_or_create_by!(sticker: sticker) { |item| item.status = :duplicate }
      end
    end
  end
end
