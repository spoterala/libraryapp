class Author < ApplicationRecord
  NAME_MAX_LENGTH = 255

  # Books keep their author even when deleted (soft delete), so an author who ever had a book
  # can't be deleted
  has_many :books, dependent: :restrict_with_error

  # "  jane   Austen " is stored as "jane Austen"; names are unique ignoring letter case
  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }, uniqueness: { case_sensitive: false }
end
