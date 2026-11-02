FactoryBot.define do
  factory :borrow_record do
    reader
    book
    borrowed_date { Date.current }

    trait :returned do
      return_date { borrowed_date + 14 }
    end
  end
end
