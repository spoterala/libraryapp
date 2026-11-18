# Books are no longer removed from the database, so their borrowing history is kept.
# Deleting a book through the API sets deleted_at instead (see Book#soft_delete).
class SoftDeleteBooks < ActiveRecord::Migration[8.1]
  def up
    add_column :books, :deleted_at, :datetime

    # A book that has borrow records can't be removed from the database at all
    remove_foreign_key :borrow_records, :books
    add_foreign_key :borrow_records, :books, on_delete: :restrict
  end

  def down
    remove_foreign_key :borrow_records, :books
    add_foreign_key :borrow_records, :books, on_delete: :cascade

    remove_column :books, :deleted_at
  end
end
