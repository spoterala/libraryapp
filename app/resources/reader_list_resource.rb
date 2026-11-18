# A reader in the list of readers. Needs params[:borrowed_counts]: reader id => number of books
# not returned yet (readers missing from it have none).
class ReaderListResource < ReaderResource
  attribute :borrowed_books_count do |reader|
    params.fetch(:borrowed_counts).fetch(reader.id, 0)
  end
end
