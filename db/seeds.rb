books = [
  { serial_number: "000001", title: "Pride and Prejudice", author: "Jane Austen" },
  { serial_number: "000002", title: "Emma", author: "Jane Austen" },
  { serial_number: "000003", title: "North and South", author: "Elizabeth Gaskell" },
  { serial_number: "000004", title: "The King's Traitor", author: "Jeff Wheeler" },
  { serial_number: "000005", title: "The Banished of Muirwood", author: "Jeff Wheeler" }
].to_h do |attributes|
  book = Book.find_or_create_by!(serial_number: attributes[:serial_number]) do |new_book|
    new_book.assign_attributes(attributes)
  end
  [ attributes[:title], book ]
end

readers = [
  { library_card_number: "100001", full_name: "Elizabeth Bennet" },
  { library_card_number: "100002", full_name: "Charlotte Lucas" },
  { library_card_number: "100003", full_name: "Owen Kiskadon" },
  { library_card_number: "100004", full_name: "Elizabeth Victoria Mortimer" },
  { library_card_number: "100005", full_name: "John Thornton" }
].to_h do |attributes|
  names = attributes[:full_name].downcase.split
  email = "#{names.first}.#{names.last}@example.com"
  reader = Reader.find_or_create_by!(library_card_number: attributes[:library_card_number]) do |new_reader|
    new_reader.assign_attributes(attributes.merge(email: email))
  end
  [ attributes[:full_name], reader ]
end


returned_loans = [
  { book: "Pride and Prejudice", reader: "Elizabeth Bennet", borrowed: "2026-05-04", returned: "2026-05-25" },
  { book: "Pride and Prejudice", reader: "Charlotte Lucas", borrowed: "2026-06-01", returned: "2026-07-10" }, # 9 days late
  { book: "Emma", reader: "Charlotte Lucas", borrowed: "2026-08-03", returned: "2026-08-20" },
  { book: "North and South", reader: "Elizabeth Bennet", borrowed: "2026-07-01", returned: "2026-07-28" },
  { book: "The King's Traitor", reader: "Owen Kiskadon", borrowed: "2026-09-01", returned: "2026-09-20" },
  { book: "The Banished of Muirwood", reader: "Elizabeth Victoria Mortimer", borrowed: "2026-06-10", returned: "2026-06-30" }
]

returned_loans.each do |loan|
  BorrowRecord.find_or_create_by!(book: books.fetch(loan[:book]), reader: readers.fetch(loan[:reader]),
                                  borrowed_date: Date.parse(loan[:borrowed])) do |record|
    record.return_date = Date.parse(loan[:returned])
  end
end

current_loans = [
  { book: "Pride and Prejudice", reader: "John Thornton", days_ago: 14 }, # due in 16 days
  { book: "North and South", reader: "Elizabeth Victoria Mortimer", days_ago: 40 }, # 10 days overdue
  { book: "The Banished of Muirwood", reader: "Owen Kiskadon", days_ago: 7 } # due in 23 days
]

current_loans.each do |loan|
  book = books.fetch(loan[:book])

  next if book.borrowed?

  book.borrow_records.create!(reader: readers.fetch(loan[:reader]),
                              borrowed_date: Date.current - loan[:days_ago])
end

puts "Seeded: #{Book.count} books, #{Reader.count} readers, #{BorrowRecord.count} borrow records " \
     "(#{BorrowRecord.not_returned.count} not returned)"
