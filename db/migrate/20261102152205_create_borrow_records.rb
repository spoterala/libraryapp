class CreateBorrowRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :borrow_records do |t|
      t.string :reader_card_number, null: false, limit: 6
      t.string :book_serial_number, null: false, limit: 6
      t.date :borrowed_date, null: false
      t.date :due_date, null: false
      t.date :return_date # empty while the book is still borrowed

      t.timestamps
    end

    add_index :borrow_records, :reader_card_number
    add_index :borrow_records, :book_serial_number
    # A book can be out on only one loan at a time
    add_index :borrow_records, :book_serial_number, unique: true, where: "return_date IS NULL",
                                                    name: "index_borrow_records_on_currently_borrowed_book"

    # Link by card / serial number. If one of those numbers changes, the records follow it.
    add_foreign_key :borrow_records, :readers, column: :reader_card_number,
                                               primary_key: :library_card_number, on_update: :cascade
    add_foreign_key :borrow_records, :books, column: :book_serial_number,
                                             primary_key: :serial_number, on_update: :cascade

    add_check_constraint :borrow_records, "due_date >= borrowed_date",
                         name: "borrow_records_due_date_not_before_borrowed_date"
    add_check_constraint :borrow_records, "return_date IS NULL OR return_date >= borrowed_date",
                         name: "borrow_records_return_date_not_before_borrowed_date"
  end
end
