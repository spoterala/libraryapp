# One loan in a book's history, with the reader's details
class BookLoanResource < LoanDatesResource
  one :reader, resource: ReaderResource
end
