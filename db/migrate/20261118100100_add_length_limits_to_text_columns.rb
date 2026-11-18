# Maximum lengths, matching the length validations in Book and Reader.
# Fails if existing data is longer; shorten those values first.
class AddLengthLimitsToTextColumns < ActiveRecord::Migration[8.1]
  def up
    change_column :books, :title, :string, limit: 255, null: false
    change_column :books, :author, :string, limit: 255, null: false
    change_column :readers, :full_name, :string, limit: 255, null: false
    change_column :readers, :email, :string, limit: 254, null: false
  end

  def down
    change_column :books, :title, :string, limit: nil, null: false
    change_column :books, :author, :string, limit: nil, null: false
    change_column :readers, :full_name, :string, limit: nil, null: false
    change_column :readers, :email, :string, limit: nil, null: false
  end
end
