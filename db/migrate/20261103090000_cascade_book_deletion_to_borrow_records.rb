class CascadeBookDeletionToBorrowRecords < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :borrow_records, :books, column: :book_serial_number
    add_foreign_key :borrow_records, :books, column: :book_serial_number,
                                             primary_key: :serial_number, on_update: :cascade, on_delete: :cascade
  end

  def down
    remove_foreign_key :borrow_records, :books, column: :book_serial_number
    add_foreign_key :borrow_records, :books, column: :book_serial_number,
                                             primary_key: :serial_number, on_update: :cascade
  end
end
