FactoryBot.define do
  factory :book do
    sequence(:serial_number, 100_000) { |n| n.to_s }
    sequence(:title) { |n| "Book #{n}" }
    sequence(:author) { |n| "Author #{n}" }
  end
end
