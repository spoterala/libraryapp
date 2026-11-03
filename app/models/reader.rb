class Reader < ApplicationRecord
  has_many :borrow_records, dependent: :restrict_with_error

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :library_card_number, presence: true,
                                  format: { with: /\A\d{6}\z/, message: "must be exactly six digits" },
                                  uniqueness: true
  validates :full_name, presence: true
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" },
                    uniqueness: true
end
