# The action isn't allowed in the record's current state, e.g. borrowing a book that is
# already borrowed. The API answers 409 with the message.
class ConflictError < StandardError
end
