# Borrow records now point to readers and books by id. Card and serial numbers stay on
# readers and books (they're what the API uses), but are no longer foreign keys.
class LinkBorrowRecordsById < ActiveRecord::Migration[8.1]
  def up
    add_reference :borrow_records, :reader, foreign_key: true # a reader with records can't be deleted
    add_reference :borrow_records, :book, foreign_key: { on_delete: :cascade } # deleting a book deletes its records

    execute <<~SQL
      UPDATE borrow_records
      SET reader_id = readers.id
      FROM readers
      WHERE readers.library_card_number = borrow_records.reader_card_number
    SQL
    execute <<~SQL
      UPDATE borrow_records
      SET book_id = books.id
      FROM books
      WHERE books.serial_number = borrow_records.book_serial_number
    SQL

    change_column_null :borrow_records, :reader_id, false
    change_column_null :borrow_records, :book_id, false

    remove_foreign_key :borrow_records, :readers, column: :reader_card_number
    remove_foreign_key :borrow_records, :books, column: :book_serial_number
    # Also drops their indexes, including the "one open loan per book" one
    remove_column :borrow_records, :reader_card_number
    remove_column :borrow_records, :book_serial_number

    # A book can be out on only one loan at a time
    add_index :borrow_records, :book_id, unique: true, where: "return_date IS NULL",
                                         name: "index_borrow_records_on_currently_borrowed_book"
  end

  def down
    add_column :borrow_records, :reader_card_number, :string, limit: 6
    add_column :borrow_records, :book_serial_number, :string, limit: 6

    execute <<~SQL
      UPDATE borrow_records
      SET reader_card_number = readers.library_card_number
      FROM readers
      WHERE readers.id = borrow_records.reader_id
    SQL
    execute <<~SQL
      UPDATE borrow_records
      SET book_serial_number = books.serial_number
      FROM books
      WHERE books.id = borrow_records.book_id
    SQL

    change_column_null :borrow_records, :reader_card_number, false
    change_column_null :borrow_records, :book_serial_number, false

    remove_index :borrow_records, name: "index_borrow_records_on_currently_borrowed_book"
    remove_reference :borrow_records, :reader, foreign_key: true
    remove_reference :borrow_records, :book, foreign_key: true

    add_index :borrow_records, :reader_card_number
    add_index :borrow_records, :book_serial_number
    add_index :borrow_records, :book_serial_number, unique: true, where: "return_date IS NULL",
                                                    name: "index_borrow_records_on_currently_borrowed_book"
    add_foreign_key :borrow_records, :readers, column: :reader_card_number,
                                               primary_key: :library_card_number, on_update: :cascade
    add_foreign_key :borrow_records, :books, column: :book_serial_number,
                                             primary_key: :serial_number, on_update: :cascade, on_delete: :cascade
  end
end
