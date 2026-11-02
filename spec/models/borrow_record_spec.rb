require "rails_helper"

RSpec.describe BorrowRecord, type: :model do
  let!(:reader) { create(:reader) }
  let!(:book) { create(:book) }

  subject(:record) do
    build(:borrow_record, reader: reader, book: book,
                          borrowed_date: Date.new(2026, 11, 1), due_date: Date.new(2026, 11, 29))
  end

  it "is valid with a reader, book, borrowed date and due date" do
    expect(record).to be_valid
  end

  describe "associations" do
    it "finds its reader by library card number" do
      expect(record.reader).to eq(reader)
    end

    it "finds its book by serial number" do
      expect(record.book).to eq(book)
    end
  end

  describe "#reader_card_number" do
    it "is required" do
      record.reader_card_number = nil

      expect(record).not_to be_valid
      expect(record.errors[:reader_card_number]).to include("can't be blank")
    end

    it "must belong to an existing reader" do
      record.reader_card_number = "999999"

      expect(record).not_to be_valid
      expect(record.errors[:reader]).to include("must exist")
    end

    it "is rejected by the database when no reader has that card number" do
      record.reader_card_number = "999999"

      expect { record.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "#book_serial_number" do
    it "is required" do
      record.book_serial_number = nil

      expect(record).not_to be_valid
      expect(record.errors[:book_serial_number]).to include("can't be blank")
    end

    it "must belong to an existing book" do
      record.book_serial_number = "999999"

      expect(record).not_to be_valid
      expect(record.errors[:book]).to include("must exist")
    end

    it "is rejected by the database when no book has that serial number" do
      record.book_serial_number = "999999"

      expect { record.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "#borrowed_date" do
    it "is required" do
      record.borrowed_date = nil

      expect(record).not_to be_valid
      expect(record.errors[:borrowed_date]).to include("can't be blank")
    end
  end

  describe "#due_date" do
    it "is optional when creating a record" do
      record.due_date = nil

      expect(record).to be_valid
    end

    it "is required when updating a record" do
      record.save!
      record.due_date = nil

      expect(record).not_to be_valid
      expect(record.errors[:due_date]).to include("can't be blank")
    end

    it "can be the same day as the borrowed date" do
      record.due_date = record.borrowed_date

      expect(record).to be_valid
    end

    it "can't be before the borrowed date" do
      record.due_date = record.borrowed_date - 1

      expect(record).not_to be_valid
      expect(record.errors[:due_date]).to include("can't be before the borrowed date")
    end

    it "is rejected by the database when before the borrowed date" do
      record.due_date = record.borrowed_date - 1

      expect { record.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /check constraint/)
    end

    describe "default of 30 days after the borrowed date (before_create)" do
      before { record.due_date = nil }

      it "has a loan period of 30 days" do
        expect(described_class::LOAN_PERIOD).to eq(30.days)
      end

      it "is set when the record is created without a due date" do
        record.save!

        expect(record.due_date).to eq(Date.new(2026, 12, 1))
      end

      it "is saved to the database" do
        record.save!

        expect(record.reload.due_date).to eq(Date.new(2026, 12, 1))
      end

      it "counts 30 calendar days across month and year boundaries" do
        record.borrowed_date = Date.new(2026, 12, 15)
        record.save!

        expect(record.due_date).to eq(Date.new(2027, 1, 14))
      end

      it "counts 30 calendar days across a leap day" do
        record.borrowed_date = Date.new(2028, 2, 15)
        record.save!

        expect(record.due_date).to eq(Date.new(2028, 3, 16))
      end

      it "is not set until the record is saved" do
        record.valid?

        expect(record.due_date).to be_nil
      end

      it "keeps a due date that was given explicitly" do
        record.due_date = Date.new(2026, 11, 8)
        record.save!

        expect(record.due_date).to eq(Date.new(2026, 11, 8))
      end

      it "is not recalculated when the record is updated" do
        record.save!
        record.update!(borrowed_date: Date.new(2026, 11, 5))

        expect(record.due_date).to eq(Date.new(2026, 12, 1))
      end

      it "is not set when the record is invalid" do
        record.borrowed_date = nil

        expect(record.save).to be(false)
        expect(record.due_date).to be_nil
      end
    end
  end

  describe "#return_date" do
    it "is empty while the book is still borrowed" do
      expect(record.return_date).to be_nil
      expect(record).not_to be_returned
    end

    it "marks the record as returned when set" do
      record.return_date = Date.new(2026, 11, 15)

      expect(record).to be_valid
      expect(record).to be_returned
    end

    it "can be after the due date (returned late)" do
      record.return_date = record.due_date + 7

      expect(record).to be_valid
    end

    it "can't be before the borrowed date" do
      record.return_date = record.borrowed_date - 1

      expect(record).not_to be_valid
      expect(record.errors[:return_date]).to include("can't be before the borrowed date")
    end

    it "is rejected by the database when before the borrowed date" do
      record.return_date = record.borrowed_date - 1

      expect { record.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /check constraint/)
    end
  end

  describe "borrowing a book that is already borrowed" do
    let!(:other_reader) { create(:reader) }

    context "when the earlier loan has not been returned" do
      before { create(:borrow_record, book: book) }

      it "is invalid" do
        record.reader_card_number = other_reader.library_card_number

        expect(record).not_to be_valid
        expect(record.errors[:book_serial_number]).to include("is already borrowed and not returned yet")
      end

      it "is rejected by the database even when validations are skipped" do
        record.reader_card_number = other_reader.library_card_number

        expect { record.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "still allows saving a returned record for the same book (history)" do
        record.assign_attributes(borrowed_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 29),
                                 return_date: Date.new(2026, 10, 20))

        expect(record).to be_valid
      end
    end

    context "when the earlier loan has been returned" do
      before do
        create(:borrow_record, :returned, book: book, borrowed_date: Date.new(2026, 10, 1))
      end

      it "is valid" do
        record.assign_attributes(reader_card_number: other_reader.library_card_number,
                                 borrowed_date: Date.new(2026, 11, 12), due_date: Date.new(2026, 12, 10))

        expect(record).to be_valid
      end
    end
  end

  describe "scopes" do
    let!(:returned_record) { create(:borrow_record, :returned) }
    let!(:current_record) { create(:borrow_record) }

    it ".not_returned returns only records without a return date" do
      expect(described_class.not_returned).to contain_exactly(current_record)
    end

    it ".returned returns only records with a return date" do
      expect(described_class.returned).to contain_exactly(returned_record)
    end
  end
end
