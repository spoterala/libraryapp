class Reader < ApplicationRecord
  FULL_NAME_MAX_LENGTH = 255
  EMAIL_MAX_LENGTH = 254 # the longest valid email address
  MAX_BORROWED_BOOKS = 5 # books borrowed at the same time (not returned yet)

  has_many :borrow_records, dependent: :restrict_with_error

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :library_card_number, presence: true,
                                  format: { with: /\A\d{6}\z/, message: "must be exactly six digits" },
                                  uniqueness: true
  validates :full_name, presence: true, length: { maximum: FULL_NAME_MAX_LENGTH }
  validates :email, presence: true,
                    length: { maximum: EMAIL_MAX_LENGTH },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" },
                    uniqueness: true
end
