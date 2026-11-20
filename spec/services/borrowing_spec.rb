require "rails_helper"

RSpec.describe Borrowing do
  let(:book) { create(:book) }
  let(:reader) { create(:reader, library_card_number: "000042") }

  describe ".borrow" do
    it "lends the book to the reader from today and returns the borrow record" do
      record = described_class.borrow(book, reader_card_number: reader.library_card_number)

      expect(record).to be_persisted
      expect(record).to have_attributes(reader: reader, book: book, borrowed_date: Date.current)
      expect(book).to be_borrowed
    end

    {
      nil => "can't be blank",
      "" => "can't be blank",
      [] => "can't be blank",
      42 => "must be a string",
      [ "000042" ] => "must be a string",
      "999999" => "doesn't match any reader"
    }.each do |card_number, message|
      it "refuses #{card_number.inspect} as the reader card number (#{message})" do
        reader

        expect { described_class.borrow(book, reader_card_number: card_number) }
          .to raise_error(InvalidInputError) { |error|
            expect(error.details).to eq(reader_card_number: [ message ])
          }
        expect(BorrowRecord.count).to eq(0)
      end
    end

    it "refuses a book that is already borrowed" do
      create(:borrow_record, book: book)

      expect { described_class.borrow(book, reader_card_number: reader.library_card_number) }
        .to raise_error(ConflictError, "Book is already borrowed")
    end

    it "refuses a deleted book" do
      book.soft_delete

      expect { described_class.borrow(book, reader_card_number: reader.library_card_number) }
        .to raise_error(ActiveRecord::RecordInvalid, /Book has been deleted/)
    end

    context "when the reader already has #{Reader::MAX_BORROWED_BOOKS} books" do
      before { create_list(:borrow_record, Reader::MAX_BORROWED_BOOKS, reader: reader) }

      it "refuses another loan" do
        expect { described_class.borrow(book, reader_card_number: reader.library_card_number) }
          .to raise_error(ConflictError, "Reader has reached the limit of 5 borrowed books")
        expect(book).to be_available
      end

      it "lends again once one of them is returned" do
        reader.borrow_records.first.mark_returned!

        expect(described_class.borrow(book, reader_card_number: reader.library_card_number)).to be_persisted
      end
    end

    it "locks the reader while lending, so two loans at once can't both pass the limit" do
      expect_any_instance_of(Reader).to receive(:lock!).and_call_original

      described_class.borrow(book, reader_card_number: reader.library_card_number)
    end

    context "when another request borrows the book at the same moment" do
      # The other loan appears after the availability check
      before do
        create(:borrow_record, book: book)
        allow(book).to receive(:borrowed?).and_return(false)
      end

      it "gives the same conflict when the model validation catches it" do
        expect { described_class.borrow(book, reader_card_number: reader.library_card_number) }
          .to raise_error(ConflictError, "Book is already borrowed")
      end

      it "gives the same conflict when the database unique index catches it" do
        allow(book).to receive(:borrow_by).and_raise(ActiveRecord::RecordNotUnique)

        expect { described_class.borrow(book, reader_card_number: reader.library_card_number) }
          .to raise_error(ConflictError, "Book is already borrowed")
      end
    end
  end

  describe ".return_book" do
    it "marks the current loan as returned today and returns it" do
      loan = create(:borrow_record, book: book, borrowed_date: Date.current - 5)

      record = described_class.return_book(book)

      expect(record).to eq(loan)
      expect(loan.reload.return_date).to eq(Date.current)
      expect(book.reload).to be_available
    end

    it "refuses a book that is not borrowed" do
      expect { described_class.return_book(book) }.to raise_error(ConflictError, "Book is not borrowed")
    end
  end
end
