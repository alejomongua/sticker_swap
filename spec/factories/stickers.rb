FactoryBot.define do
  factory :sticker do
    prefix { "ST" }
    sequence(:number) { |n| n }
    sequence(:name) { |n| "Equipo #{n}" }
    photo { nil }
    group_name { "Grupo A" }
  end
end
