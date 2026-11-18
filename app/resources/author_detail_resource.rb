# An author with their books (not deleted ones), ordered by title
class AuthorDetailResource < AuthorResource
  many :books,
       proc { |books| books.kept.includes(:author, :current_borrow_record).order(:title, :serial_number) },
       resource: "BookResource"
end
