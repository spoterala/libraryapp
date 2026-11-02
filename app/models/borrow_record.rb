class BorrowRecord < ApplicationRecord
  LOAN_PERIOD = 30.days

  belongs_to :reader, foreign_key: :reader_card_number, primary_key: :library_card_number,
                      inverse_of: :borrow_records
  belongs_to :book, foreign_key: :book_serial_number, primary_key: :serial_number,
                    inverse_of: :borrow_records

  scope :not_returned, -> { where(return_date: nil) }
  scope :returned, -> { where.not(return_date: nil) }

  validates :reader_card_number, presence: true
  validates :book_serial_number, presence: true,
                                 uniqueness: { conditions: -> { not_returned },
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

  def returned?
    return_date.present?
  end

  def not_returned?
    !returned?
  end

  private

  # Default loan period: due LOAN_PERIOD after borrowing, unless a due_date was given
  def set_due_date
    self.due_date ||= borrowed_date + LOAN_PERIOD
  end
end
