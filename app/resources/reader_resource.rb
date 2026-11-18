# A reader's own details (a new reader, the reader of a loan in a book's history)
class ReaderResource
  include Alba::Resource

  attributes :library_card_number, :full_name, :email
end
