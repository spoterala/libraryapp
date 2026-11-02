FactoryBot.define do
  factory :reader do
    sequence(:library_card_number, 100_000) { |n| n.to_s }
    sequence(:full_name) { |n| "Reader #{n}" }
    sequence(:email) { |n| "reader#{n}@example.com" }
  end
end
