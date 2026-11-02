require "rails_helper"

RSpec.describe Book, type: :model do
  subject(:book) { build(:book) }

  it "is valid with a six-digit serial number, title and author" do
    expect(book).to be_valid
  end

  describe "#serial_number" do
    it "is required" do
      book.serial_number = nil

      expect(book).not_to be_valid
      expect(book.errors[:serial_number]).to include("can't be blank")
    end

    it "keeps leading zeros" do
      book.serial_number = "000042"
      book.save!

      expect(book.reload.serial_number).to eq("000042")
    end

    ["12345", "1234567", "12a456", "abcdef", "123 45", " 123456"].each do |serial|
      it "rejects #{serial.inspect} because it is not exactly six digits" do
        book.serial_number = serial

        expect(book).not_to be_valid
        expect(book.errors[:serial_number]).to include("must be exactly six digits")
      end
    end

    context "when another book already has the same serial number" do
      before { create(:book, serial_number: book.serial_number) }

      it "is invalid" do
        expect(book).not_to be_valid
        expect(book.errors[:serial_number]).to include("has already been taken")
      end

      it "is rejected by the database even when validations are skipped" do
        expect { book.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#title" do
    it "is required" do
      book.title = ""

      expect(book).not_to be_valid
      expect(book.errors[:title]).to include("can't be blank")
    end
  end

  describe "#author" do
    it "is required" do
      book.author = ""

      expect(book).not_to be_valid
      expect(book.errors[:author]).to include("can't be blank")
    end
  end

  describe "#borrow_records" do
    let!(:reader) { create(:reader) }

    before { book.save! }

    it "lists the book's borrow records" do
      record = create(:borrow_record, reader: reader, book: book)

      expect(book.borrow_records).to contain_exactly(record)
    end

    it "prevents deleting a book that has borrow records" do
      create(:borrow_record, reader: reader, book: book)

      expect(book.destroy).to be(false)
      expect(book.errors[:base]).to include("Cannot delete record because dependent borrow records exist")
    end

    it "updates the borrow records when the serial number changes" do
      record = create(:borrow_record, reader: reader, book: book)

      book.update!(serial_number: "555555")

      expect(record.reload.book_serial_number).to eq("555555")
    end
  end
end
