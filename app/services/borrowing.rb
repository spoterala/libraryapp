# Lending books to readers and taking them back.
# Raises InvalidInputError for bad input and ConflictError when the book's state doesn't
# allow the action; ApplicationController turns them into 422 and 409 responses.
module Borrowing
  ALREADY_BORROWED = "Book is already borrowed"
  NOT_BORROWED = "Book is not borrowed"

  module_function

  # Lends the book to the reader with this card number, from today. Returns the borrow record.
  def borrow(book, reader_card_number:)
    reader = find_reader(reader_card_number)
    raise ConflictError, ALREADY_BORROWED if book.borrowed?

    record = book.borrow_by(reader)
    return record if record.persisted?
    # Another request lent the book after the check above, and the model validation caught it
    raise ConflictError, ALREADY_BORROWED if record.errors.of_kind?(:book, :taken)

    raise ActiveRecord::RecordInvalid, record
  rescue ActiveRecord::RecordNotUnique # the database unique index caught a simultaneous loan
    raise ConflictError, ALREADY_BORROWED
  end

  # Marks the book's current loan as returned today. Returns the borrow record.
  def return_book(book)
    record = book.current_borrow_record
    raise ConflictError, NOT_BORROWED unless record

    record.mark_returned!
    record
  end

  def find_reader(card_number)
    raise invalid_card_number("can't be blank") if card_number.blank?
    # Otherwise an array would be looked up as "any of these card numbers"
    raise invalid_card_number("must be a string") unless card_number.is_a?(String)

    Reader.find_by(library_card_number: card_number) || raise(invalid_card_number("doesn't match any reader"))
  end

  def invalid_card_number(message)
    InvalidInputError.new(reader_card_number: [ message ])
  end
  private_class_method :find_reader, :invalid_card_number
end
