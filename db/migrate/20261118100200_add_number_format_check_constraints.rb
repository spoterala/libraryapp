# Serial and library card numbers must be exactly six digits, like the model validations
# (/\A\d{6}\z/), also when data is written without them.
class AddNumberFormatCheckConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :books, "serial_number ~ '^[0-9]{6}$'", name: "books_serial_number_six_digits"
    add_check_constraint :readers, "library_card_number ~ '^[0-9]{6}$'",
                         name: "readers_library_card_number_six_digits"
  end
end
