FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { password }
    receive_offer_notifications { true }
    sequence(:username) { |n| "usuario#{n}" }
  end
end
