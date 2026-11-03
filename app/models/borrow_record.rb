class BorrowRecord < ApplicationRecord
  LOAN_PERIOD = 30.days

  # Linked by id. The API shows the reader's card number and the book's serial number instead.
  belongs_to :reader
  belongs_to :book

  scope :not_returned, -> { where(return_date: nil) }
  scope :returned, -> { where.not(return_date: nil) }

  # belongs_to already requires the reader and the book to exist ("must exist")
  validates :book, uniqueness: { conditions: -> { not_returned },
                                 message: "is already borrowed and not returned yet" },
                   if: :not_returned?
  validates :borrowed_date, presence: true
  # On create, a missing due_date is filled in by set_due_date (which runs after validation)
  validates :due_date, presence: true, on: :update
  validates :due_date, comparison: { greater_than_or_equal_to: :borrowed_date,
                                     message: "can't be before the borrowed date" },
                       allow_nil: true, if: :borrowed_date
  validates :return_date, comparison: { greater_than_or_equal_to: :borrowed_date,
                                        message: "can't be before the borrowed date" },
                          allow_nil: true, if: :borrowed_date

  before_create :set_due_date

  def reader_card_number
    reader&.library_card_number
  end

  def book_serial_number
    book&.serial_number
  end

  def returned?
    return_date.present?
  end

  def not_returned?
    !returned?
  end

  def mark_returned!
    update!(return_date: Date.current)
  end

  private

  # Default loan period: due LOAN_PERIOD after borrowing, unless a due_date was given
  def set_due_date
    self.due_date ||= borrowed_date + LOAN_PERIOD
  end
end
