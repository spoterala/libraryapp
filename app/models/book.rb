class Book < ApplicationRecord
  # Deleting a book deletes its borrow records too (the database also cascades the delete),
  # but a book that is borrowed right now can't be deleted (see ensure_not_borrowed)
  has_many :borrow_records, dependent: :delete_all
  has_one :current_borrow_record, -> { not_returned }, class_name: "BorrowRecord"

  validates :serial_number, presence: true,
                            format: { with: /\A\d{6}\z/, message: "must be exactly six digits" },
                            uniqueness: true
  validates :title, presence: true
  validates :author, presence: true

  before_destroy :ensure_not_borrowed, prepend: true

  def available?
    current_borrow_record.nil?
  end

  def borrowed?
    !available?
  end

  def borrow_by(reader)
    record = borrow_records.create(reader: reader, borrowed_date: Date.current)
    reset_current_borrow_record if record.persisted?
    record
  end

  private

  def ensure_not_borrowed
    return unless borrowed?

    errors.add(:base, "Cannot delete a book that is currently borrowed")
    throw :abort
  end
end
