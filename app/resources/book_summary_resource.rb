# A book's own details, e.g. inside a reader's borrowing history
class BookSummaryResource
  include Alba::Resource

  attributes :serial_number, :title, :author
end
