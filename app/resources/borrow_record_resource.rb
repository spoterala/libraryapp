# A borrow record on its own (the answer to borrowing and returning a book)
class BorrowRecordResource < LoanDatesResource
  attributes :book_serial_number, :reader_card_number
end
