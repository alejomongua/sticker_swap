FactoryBot.define do
  factory :swap_offer do
    association :sender, factory: :user
    association :receiver, factory: :user
    association :offered_sticker, factory: :sticker
    association :requested_sticker, factory: :sticker
    status { :pending }

    after(:build) do |offer|
      next unless offer.sender&.persisted? && offer.receiver&.persisted? && offer.offered_sticker&.persisted? && offer.requested_sticker&.persisted?

      offer.sender.inventory_items.find_or_create_by!(sticker: offer.offered_sticker) { |item| item.status = :duplicate }
      offer.sender.inventory_items.find_or_create_by!(sticker: offer.requested_sticker) { |item| item.status = :missing }
      offer.receiver.inventory_items.find_or_create_by!(sticker: offer.requested_sticker) { |item| item.status = :duplicate }
      offer.receiver.inventory_items.find_or_create_by!(sticker: offer.offered_sticker) { |item| item.status = :missing }
    end
  end
end
