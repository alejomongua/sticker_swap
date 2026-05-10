FactoryBot.define do
  factory :user do
    transient do
      create_default_group { true }
    end

    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { password }
    receive_offer_notifications { true }
    sequence(:username) { |n| "usuario#{n}" }

    after(:create) do |user, evaluator|
      user.update_column(:receive_offer_notifications, evaluator.receive_offer_notifications)

      next unless evaluator.create_default_group
      next if user.groups.exists?

      group = create(:group, admin_user: user)
      user.reload.update!(active_group: group) if user.active_group != group
    end
  end
end
