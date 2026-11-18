# A book with its whole borrowing history, newest loan first
class BookDetailResource < BookResource
  many :borrow_records,
       proc { |records| records.includes(:reader).order(borrowed_date: :desc, id: :desc) },
       resource: "BookLoanResource"
end
