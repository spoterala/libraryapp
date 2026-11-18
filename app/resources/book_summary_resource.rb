# A book's own details, e.g. inside a reader's borrowing history
class BookSummaryResource
  include Alba::Resource

  attributes :serial_number, :title, :author_id

  # The author's name, as a string
  attribute :author do |book|
    book.author.name
  end
end
