FactoryBot.define do
  factory :inventory_item do
    association :user
    association :sticker
    quantity { 1 }
    status { :missing }

    trait :duplicate do
      status { :duplicate }
    end
  end
end
