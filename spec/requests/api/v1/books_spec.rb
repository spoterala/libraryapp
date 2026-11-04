require "rails_helper"

RSpec.describe "Books API", type: :request do
  let(:json) { response.parsed_body }

  describe "GET /api/v1/books" do
    it "returns an empty list when there are no books" do
      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end

    it "lists books ordered by serial number, with their availability" do
      available = create(:book, serial_number: "000002", title: "Pride and Prejudice", author: "Jane Austen")
      borrowed = create(:book, serial_number: "000001")
      returned = create(:book, serial_number: "000003")
      loan = create(:borrow_record, book: borrowed)
      create(:borrow_record, :returned, book: returned)

      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(json.map { it["serial_number"] }).to eq(%w[000001 000002 000003])
      expect(json[0]).to include("status" => "borrowed", "due_date" => loan.due_date.iso8601)
      expect(json[1]).to eq("serial_number" => available.serial_number, "title" => "Pride and Prejudice",
                            "author" => "Jane Austen", "status" => "available", "due_date" => nil)
      expect(json[2]).to include("status" => "available", "due_date" => nil)
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    let!(:book) { create(:book, serial_number: "000123", title: "North and South", author: "Elizabeth Gaskell") }

    it "returns an available book with an empty history" do
      get "/api/v1/books/000123"

      expect(response).to have_http_status(:ok)
      expect(json).to eq("serial_number" => "000123", "title" => "North and South", "author" => "Elizabeth Gaskell",
                         "status" => "available", "due_date" => nil, "borrow_records" => [])
    end

    it "returns the full borrowing history, newest first, with the readers' details" do
      first_reader = create(:reader, library_card_number: "000001", full_name: "Elizabeth Bennet",
                                     email: "elizabeth.bennet@example.com")
      second_reader = create(:reader, library_card_number: "000002")
      create(:borrow_record, book: book, reader: first_reader,
                             borrowed_date: Date.new(2026, 5, 4), return_date: Date.new(2026, 5, 25))
      current = create(:borrow_record, book: book, reader: second_reader, borrowed_date: Date.current - 3)

      get "/api/v1/books/000123"

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "borrowed", "due_date" => current.due_date.iso8601)
      expect(json["borrow_records"]).to eq([
        { "borrowed_date" => (Date.current - 3).iso8601, "due_date" => current.due_date.iso8601,
          "return_date" => nil,
          "reader" => { "library_card_number" => "000002", "full_name" => second_reader.full_name,
                        "email" => second_reader.email } },
        { "borrowed_date" => "2026-05-04", "due_date" => "2026-06-03", "return_date" => "2026-05-25",
          "reader" => { "library_card_number" => "000001", "full_name" => "Elizabeth Bennet",
                        "email" => "elizabeth.bennet@example.com" } }
      ])
    end

    it "doesn't include other books' loans" do
      create(:borrow_record, book: create(:book))

      get "/api/v1/books/000123"

      expect(json["borrow_records"]).to eq([])
    end

    it "returns 404 for an unknown serial number" do
      get "/api/v1/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Book not found")
    end
  end

  describe "POST /api/v1/books" do
    let(:params) { { book: { serial_number: "000123", title: "Emma", author: "Jane Austen" } } }

    it "creates a book" do
      expect { post "/api/v1/books", params: params, as: :json }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to eq("serial_number" => "000123", "title" => "Emma", "author" => "Jane Austen",
                         "status" => "available", "due_date" => nil)
    end

    it "returns validation errors for invalid data" do
      post "/api/v1/books", params: { book: { serial_number: "12", title: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to include("serial_number" => [ "must be exactly six digits" ],
                                        "title" => [ "can't be blank" ],
                                        "author" => [ "can't be blank" ])
    end

    it "rejects a duplicate serial number" do
      create(:book, serial_number: "000123")

      expect { post "/api/v1/books", params: params, as: :json }.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["serial_number"]).to include("has already been taken")
    end

    it "returns 400 when the book parameters are missing" do
      post "/api/v1/books", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to be_present
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    let!(:book) { create(:book, serial_number: "000123") }

    it "deletes a book" do
      expect { delete "/api/v1/books/000123" }.to change(Book, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it "deletes a book whose loans were returned, together with its borrow records" do
      create(:borrow_record, :returned, book: book)

      expect { delete "/api/v1/books/000123" }.to change(BorrowRecord, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Book.exists?(book.id)).to be(false)
    end

      # The book with its whole borrowing history, newest loan first
    it "refuses to delete a book that is currently borrowed" do
      create(:borrow_record, book: book)

      expect { delete "/api/v1/books/000123" }.not_to change(Book, :count)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq("Cannot delete a book that is currently borrowed")
    end

    it "returns 404 for an unknown serial number" do
      delete "/api/v1/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Book not found")
    end
  end

  describe "POST /api/v1/books/:serial_number/borrow" do
    let!(:book) { create(:book, serial_number: "000123") }
    let!(:reader) { create(:reader, library_card_number: "000042") }

    it "lends the book to the reader from today, due in 30 days" do
      expect do
        post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json
      end.to change(BorrowRecord, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to eq("book_serial_number" => "000123", "reader_card_number" => "000042",
                         "borrowed_date" => Date.current.iso8601,
                         "due_date" => (Date.current + 30).iso8601,
                         "return_date" => nil)
      expect(book.reload).to be_borrowed
    end

    it "lends a book again after it was returned" do
      create(:borrow_record, :returned, book: book)

      post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json

      expect(response).to have_http_status(:created)
    end

    it "refuses a book that is already borrowed" do
      create(:borrow_record, book: book)

      expect do
        post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json
      end.not_to change(BorrowRecord, :count)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq("Book is already borrowed")
    end

    it "returns 422 for an unknown reader card number" do
      post "/api/v1/books/000123/borrow", params: { reader_card_number: "999999" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq("reader_card_number" => [ "doesn't match any reader" ])
    end

    it "returns 422 when the reader card number is missing" do
      post "/api/v1/books/000123/borrow", params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq("reader_card_number" => [ "can't be blank" ])
    end

    context "when another request borrows the book at the same moment" do
      # The other loan appears after this request checked that the book is available
      before do
        create(:borrow_record, book: book)
        allow(Book).to receive(:find_by!).with(serial_number: "000123").and_return(book)
      end

      it "returns 422 when the model validation catches it" do
        allow(book).to receive(:borrowed?).and_return(false)

        post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to eq("book" => [ "is already borrowed and not returned yet" ])
      end

      it "returns 409 when the database unique index catches it" do
        allow(book).to receive(:borrowed?).and_return(false)
        allow(book).to receive(:borrow_by).and_raise(ActiveRecord::RecordNotUnique)

        post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json

        expect(response).to have_http_status(:conflict)
        expect(json["error"]).to eq("Conflicts with an existing record")
      end
    end

    it "returns 404 for an unknown serial number" do
      post "/api/v1/books/999999/borrow", params: { reader_card_number: "000042" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Book not found")
    end
  end

  describe "POST /api/v1/books/:serial_number/return" do
    let!(:book) { create(:book, serial_number: "000123") }

    it "marks the current loan as returned today" do
      loan = create(:borrow_record, book: book, borrowed_date: Date.current - 5)

      post "/api/v1/books/000123/return"

      expect(response).to have_http_status(:ok)
      expect(json).to include("book_serial_number" => "000123",
                              "reader_card_number" => loan.reader_card_number,
                              "borrowed_date" => (Date.current - 5).iso8601,
                              "return_date" => Date.current.iso8601)
      expect(loan.reload).to be_returned
      expect(book.reload).to be_available
    end

    it "refuses a book that is not borrowed" do
      create(:borrow_record, :returned, book: book)

      post "/api/v1/books/000123/return"

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq("Book is not borrowed")
    end

    it "returns 404 for an unknown serial number" do
      post "/api/v1/books/999999/return"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Book not found")
    end
  end
end
