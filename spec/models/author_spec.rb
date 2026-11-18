require "rails_helper"

RSpec.describe Author, type: :model do
  subject(:author) { build(:author, name: "Jane Austen") }

  it "is valid with a name" do
    expect(author).to be_valid
  end

  describe "#name" do
    it "is required" do
      author.name = " "

      expect(author).not_to be_valid
      expect(author.errors[:name]).to include("can't be blank")
    end

    it "is stored without extra spaces" do
      author.name = "  Jane   Austen "

      expect(author.name).to eq("Jane Austen")
    end

    it "can be up to 255 characters long" do
      author.name = "a" * 255

      expect(author).to be_valid
    end

    it "can't be longer than 255 characters" do
      author.name = "a" * 256

      expect(author).not_to be_valid
      expect(author.errors[:name]).to include("is too long (maximum is 255 characters)")
    end

    it "is limited by the database too" do
      author.name = "a" * 256

      expect { author.save!(validate: false) }.to raise_error(ActiveRecord::ValueTooLong)
    end

    context "when another author already has the same name in different letter case" do
      before { create(:author, name: "JANE AUSTEN") }

      it "is invalid" do
        expect(author).not_to be_valid
        expect(author.errors[:name]).to include("has already been taken")
      end

      it "is rejected by the database even when validations are skipped" do
        expect { author.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#books" do
    before { author.save! }

    it "lists the author's books" do
      book = create(:book, author: author)

      expect(author.books).to contain_exactly(book)
    end

    it "can be deleted when they have no books" do
      expect(author.destroy).to be_truthy
    end

    it "can't be deleted while they have books, even deleted ones" do
      create(:book, author: author).soft_delete

      expect(author.destroy).to be(false)
      expect(author.errors[:base]).to include("Cannot delete record because dependent books exist")
    end

    it "is protected by the database too" do
      create(:book, author: author)

      expect { author.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
