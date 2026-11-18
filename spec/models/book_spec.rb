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

    ["12345", "12a456", "abcdef", "12 456"].each do |serial|
      it "is rejected by the database as #{serial.inspect} even when validations are skipped" do
        book.serial_number = serial

        expect { book.save!(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
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

  %i[title author].each do |attribute|
    describe "##{attribute}" do
      it "is required" do
        book[attribute] = ""

        expect(book).not_to be_valid
        expect(book.errors[attribute]).to include("can't be blank")
      end

      it "can be up to 255 characters long" do
        book[attribute] = "a" * 255

        expect(book).to be_valid
      end

      it "can't be longer than 255 characters" do
        book[attribute] = "a" * 256

        expect(book).not_to be_valid
        expect(book.errors[attribute]).to include("is too long (maximum is 255 characters)")
      end

      it "is limited by the database too" do
        book[attribute] = "a" * 256

        expect { book.save!(validate: false) }.to raise_error(ActiveRecord::ValueTooLong)
      end
    end
  end

  describe "#borrow_records" do
    let!(:reader) { create(:reader) }

    before { book.save! }

    it "lists the book's borrow records" do
      record = create(:borrow_record, reader: reader, book: book)

      expect(book.borrow_records).to contain_exactly(record)
    end

    it "can't be removed from the database while it has borrow records, so the history is kept" do
      record = create(:borrow_record, :returned, reader: reader, book: book)

      expect(book.destroy).to be(false)
      expect(book.errors[:base]).to include("Cannot delete record because dependent borrow records exist")
      expect(BorrowRecord.exists?(record.id)).to be(true)
    end

    it "is protected by the database too (the foreign key restricts deletion)" do
      create(:borrow_record, :returned, reader: reader, book: book)

      expect { book.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "can be removed from the database when it has no borrow records" do
      expect(book.destroy).to be_truthy
      expect(Book.exists?(book.id)).to be(false)
    end

    it "keeps its borrow records when the serial number changes (they link by id)" do
      record = create(:borrow_record, reader: reader, book: book)

      book.update!(serial_number: "555555")

      expect(record.reload.book).to eq(book)
      expect(record.book_serial_number).to eq("555555")
    end
  end

  describe "#current_borrow_record, #available? and #borrowed?" do
    before { book.save! }

    it "has no current borrow record and is available when never borrowed" do
      expect(book.current_borrow_record).to be_nil
      expect(book).to be_available
      expect(book).not_to be_borrowed
    end

    it "is borrowed while a loan is not returned" do
      record = create(:borrow_record, book: book)

      expect(book.current_borrow_record).to eq(record)
      expect(book).to be_borrowed
      expect(book).not_to be_available
    end

    it "is available again after the loan is returned" do
      create(:borrow_record, :returned, book: book)

      expect(book.current_borrow_record).to be_nil
      expect(book).to be_available
    end
  end

  describe "#borrow_by" do
    let(:reader) { create(:reader) }

    before { book.save! }

    it "creates a loan for the reader from today, due in 30 days" do
      record = book.borrow_by(reader)

      expect(record).to be_persisted
      expect(record.reader).to eq(reader)
      expect(record.borrowed_date).to eq(Date.current)
      expect(record.due_date).to eq(Date.current + 30)
      expect(book).to be_borrowed
    end

    it "returns an unsaved record with errors when the book is already borrowed" do
      book.borrow_by(create(:reader))

      record = book.borrow_by(reader)

      expect(record).not_to be_persisted
      expect(record.errors[:book]).to include("is already borrowed and not returned yet")
    end
  end

  describe "#soft_delete, #deleted? and .kept" do
    before { book.save! }

    it "is not deleted when created" do
      expect(book).not_to be_deleted
      expect(Book.kept).to contain_exactly(book)
    end

    it "marks the book as deleted, keeping it and its borrow records" do
      record = create(:borrow_record, :returned, book: book)

      expect(book.soft_delete).to be(true)

      expect(book.reload).to be_deleted
      expect(Book.kept).to be_empty
      expect(Book.exists?(book.id)).to be(true)
      expect(BorrowRecord.exists?(record.id)).to be(true)
    end

    it "refuses to delete a book that is currently borrowed" do
      create(:borrow_record, book: book)

      expect(book.soft_delete).to be(false)

      expect(book.errors[:base]).to include("Cannot delete a book that is currently borrowed")
      expect(book.reload).not_to be_deleted
    end
  end
end
