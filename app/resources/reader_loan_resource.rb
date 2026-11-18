# One loan in a reader's history, with the book's details
class ReaderLoanResource < LoanDatesResource
  one :book, resource: BookSummaryResource
end
