class Book < ApplicationRecord
  has_many :borrow_records, foreign_key: :book_serial_number, primary_key: :serial_number,
                            inverse_of: :book,
                            dependent: :restrict_with_error # keep the borrowing history

  validates :serial_number, presence: true,
                            format: { with: /\A\d{6}\z/, message: "must be exactly six digits" },
                            uniqueness: true
  validates :title, presence: true
  validates :author, presence: true
end
