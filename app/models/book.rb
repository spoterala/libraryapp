class Book < ApplicationRecord
  TITLE_MAX_LENGTH = 255

  # Books with borrow records are never removed from the database, so the borrowing history
  # is kept. Deleting a book through the API marks it as deleted instead (see soft_delete).
  has_many :borrow_records, dependent: :restrict_with_error
  # Presence is checked by author_present, with messages that fit the API
  belongs_to :author, optional: true
  has_one :current_borrow_record, -> { not_returned }, class_name: "BorrowRecord"

  # Books that haven't been deleted. Deleted books keep their serial numbers: they can't be reused.
  scope :kept, -> { where(deleted_at: nil) }

  validates :serial_number, presence: true,
                            format: { with: /\A\d{6}\z/, message: "must be exactly six digits" },
                            uniqueness: true
  validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
  validate :author_present

  def available?
    current_borrow_record.nil?
  end

  def borrowed?
    !available?
  end

  def deleted?
    deleted_at.present?
  end

  # Hides the book from the API but keeps it and its borrowing history.
  # Returns false (with an error) if the book is borrowed right now.
  def soft_delete
    if borrowed?
      errors.add(:base, "Cannot delete a book that is currently borrowed")
      return false
    end

    update_columns(deleted_at: Time.current, updated_at: Time.current)
  end

  def borrow_by(reader)
    record = borrow_records.create(reader: reader, borrowed_date: Date.current)
    reset_current_borrow_record if record.persisted?
    record
  end

  private

  def author_present
    return if author

    errors.add(:author_id, author_id.present? ? "doesn't match any author" : "can't be blank")
  end
end
