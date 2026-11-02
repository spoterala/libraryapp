class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |t|
      t.string :library_card_number, null: false, limit: 6
      t.string :full_name, null: false
      t.string :email, null: false

      t.timestamps
    end
    add_index :readers, :library_card_number, unique: true
    add_index :readers, :email, unique: true
  end
end
