require "rails_helper"

RSpec.describe Reader, type: :model do
  subject(:reader) { build(:reader) }

  it "is valid with a six-digit library card number, full name and email" do
    expect(reader).to be_valid
  end

  describe "#library_card_number" do
    it "is required" do
      reader.library_card_number = nil

      expect(reader).not_to be_valid
      expect(reader.errors[:library_card_number]).to include("can't be blank")
    end

    it "keeps leading zeros" do
      reader.library_card_number = "000042"
      reader.save!

      expect(reader.reload.library_card_number).to eq("000042")
    end

    ["12345", "1234567", "12a456", "abcdef", "123 45", " 123456"].each do |number|
      it "rejects #{number.inspect} because it is not exactly six digits" do
        reader.library_card_number = number

        expect(reader).not_to be_valid
        expect(reader.errors[:library_card_number]).to include("must be exactly six digits")
      end
    end

    context "when another reader already has the same library card number" do
      before { create(:reader, library_card_number: reader.library_card_number) }

      it "is invalid" do
        expect(reader).not_to be_valid
        expect(reader.errors[:library_card_number]).to include("has already been taken")
      end

      it "is rejected by the database even when validations are skipped" do
        expect { reader.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#full_name" do
    it "is required" do
      reader.full_name = ""

      expect(reader).not_to be_valid
      expect(reader.errors[:full_name]).to include("can't be blank")
    end
  end

  describe "#email" do
    it "is required" do
      reader.email = ""

      expect(reader).not_to be_valid
      expect(reader.errors[:email]).to include("can't be blank")
    end

    it "is stored trimmed and lowercased" do
      reader.email = "  Elizabeth.Bennet@Pemberly.COM "

      expect(reader.email).to eq("elizabeth.bennet@pemberly.com")
    end

    ["plainaddress", "@pemberly.com", "elizabeth@", "elizabeth bennet@pemberly.com"].each do |email|
      it "rejects #{email.inspect} because it is not a valid email address" do
        reader.email = email

        expect(reader).not_to be_valid
        expect(reader.errors[:email]).to include("is not a valid email address")
      end
    end

    context "when another reader already has the same email" do
      before { create(:reader, email: reader.email) }

      it "is invalid" do
        expect(reader).not_to be_valid
        expect(reader.errors[:email]).to include("has already been taken")
      end

      it "is invalid when the email differs only in letter case or spaces" do
        reader.email = "  #{reader.email.upcase} "

        expect(reader).not_to be_valid
        expect(reader.errors[:email]).to include("has already been taken")
      end

      it "is rejected by the database even when validations are skipped" do
        expect { reader.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#borrow_records" do
    let!(:book) { create(:book) }

    before { reader.save! }

    it "lists the reader's borrow records" do
      record = create(:borrow_record, reader: reader, book: book)

      expect(reader.borrow_records).to contain_exactly(record)
    end

    it "prevents deleting a reader who has borrow records" do
      create(:borrow_record, reader: reader, book: book)

      expect(reader.destroy).to be(false)
      expect(reader.errors[:base]).to include("Cannot delete record because dependent borrow records exist")
    end

    it "keeps its borrow records when the library card number changes (they link by id)" do
      record = create(:borrow_record, reader: reader, book: book)

      reader.update!(library_card_number: "555555")

      expect(record.reload.reader).to eq(reader)
      expect(record.reader_card_number).to eq("555555")
    end

    it "is rejected by the database when deleting a reader who has borrow records" do
      create(:borrow_record, reader: reader, book: book)

      expect { reader.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
