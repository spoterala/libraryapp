# A book with its availability (list of books, a new or updated book).
# Preload current_borrow_record when serializing many books.
class BookResource < BookSummaryResource
  attribute :status do |book|
    book.borrowed? ? "borrowed" : "available"
  end

  # Only while the book is borrowed, otherwise nil
  attribute :due_date do |book|
    book.current_borrow_record&.due_date
  end
end
