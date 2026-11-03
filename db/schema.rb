# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_03_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "books", force: :cascade do |t|
    t.string "serial_number", limit: 6, null: false
    t.string "title", null: false
    t.string "author", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial_number"], name: "index_books_on_serial_number", unique: true
  end

  create_table "borrow_records", force: :cascade do |t|
    t.date "borrowed_date", null: false
    t.date "due_date", null: false
    t.date "return_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "reader_id", null: false
    t.bigint "book_id", null: false
    t.index ["book_id"], name: "index_borrow_records_on_book_id"
    t.index ["book_id"], name: "index_borrow_records_on_currently_borrowed_book", unique: true, where: "(return_date IS NULL)"
    t.index ["reader_id"], name: "index_borrow_records_on_reader_id"
    t.check_constraint "due_date >= borrowed_date", name: "borrow_records_due_date_not_before_borrowed_date"
    t.check_constraint "return_date IS NULL OR return_date >= borrowed_date", name: "borrow_records_return_date_not_before_borrowed_date"
  end

  create_table "readers", force: :cascade do |t|
    t.string "library_card_number", limit: 6, null: false
    t.string "full_name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_readers_on_email", unique: true
    t.index ["library_card_number"], name: "index_readers_on_library_card_number", unique: true
  end

  add_foreign_key "borrow_records", "books", on_delete: :cascade
  add_foreign_key "borrow_records", "readers"
end
