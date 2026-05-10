FactoryBot.define do
  factory :group do
    association :admin_user, factory: :user, create_default_group: false
    sequence(:name) { |n| "Grupo #{n}" }
    registration_open { true }

    after(:create) do |group|
      group.admin_user.reload.update!(active_group: group) if group.admin_user.active_group != group
    end
  end
end
