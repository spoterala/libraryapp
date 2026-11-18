# A reader with their whole borrowing history, newest loan first
class ReaderDetailResource < ReaderResource
  many :borrow_records,
       proc { |records| records.includes(:book).order(borrowed_date: :desc, id: :desc) },
       resource: "ReaderLoanResource"
end
