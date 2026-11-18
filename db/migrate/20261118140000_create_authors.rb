# Authors get their own table; books link to one author by id instead of a text field.
# Existing author texts become authors. Spellings that differ only in letter case or spacing
# become one author, named after the most common spelling.
class CreateAuthors < ActiveRecord::Migration[8.1]
  def up
    create_table :authors do |t|
      t.string :name, limit: 255, null: false
      t.timestamps
    end
    add_index :authors, "lower(name)", unique: true, name: "index_authors_on_lower_name"

    add_reference :books, :author, foreign_key: true # an author with books can't be deleted
    move_author_texts_to_authors
    change_column_null :books, :author_id, false
    remove_column :books, :author
  end

  def down
    add_column :books, :author, :string, limit: 255
    execute <<~SQL
      UPDATE books SET author = authors.name FROM authors WHERE authors.id = books.author_id
    SQL
    change_column_null :books, :author, false
    remove_reference :books, :author, foreign_key: true
    drop_table :authors
  end

  private

  # Names are squished like Author's `normalizes` (written out here so the migration doesn't
  # depend on the model changing later)
  def move_author_texts_to_authors
    books = select_rows("SELECT id, author FROM books ORDER BY id")

    books.group_by { |_id, author| author.squish.downcase }.each_value do |group|
      spellings = group.map { |_id, author| author.squish }.tally # in order of first use
      name = spellings.each_with_index.max_by { |(_spelling, count), index| [ count, -index ] }.first.first

      author_id = select_value(<<~SQL)
        INSERT INTO authors (name, created_at, updated_at) VALUES (#{quote(name)}, NOW(), NOW()) RETURNING id
      SQL
      execute("UPDATE books SET author_id = #{author_id} WHERE id IN (#{group.map(&:first).join(', ')})")
    end
  end
end
