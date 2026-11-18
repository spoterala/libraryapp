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
      austen = create(:author, name: "Jane Austen")
      available = create(:book, serial_number: "000002", title: "Pride and Prejudice", author: austen)
      borrowed = create(:book, serial_number: "000001")
      returned = create(:book, serial_number: "000003")
      loan = create(:borrow_record, book: borrowed)
      create(:borrow_record, :returned, book: returned)

      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(json.map { it["serial_number"] }).to eq(%w[000001 000002 000003])
      expect(json[0]).to include("status" => "borrowed", "due_date" => loan.due_date.iso8601)
      expect(json[1]).to eq("serial_number" => available.serial_number, "title" => "Pride and Prejudice",
                            "author_id" => austen.id, "author" => "Jane Austen",
                            "status" => "available", "due_date" => nil)
      expect(json[2]).to include("status" => "available", "due_date" => nil)
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    let!(:book) { create(:book, serial_number: "000123", title: "North and South",
                                 author: create(:author, name: "Elizabeth Gaskell")) }

    it "returns an available book with an empty history" do
      get "/api/v1/books/000123"

      expect(response).to have_http_status(:ok)
      expect(json).to eq("serial_number" => "000123", "title" => "North and South",
                         "author_id" => book.author_id, "author" => "Elizabeth Gaskell",
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
      expect(json.dig("error", "message")).to eq("Book not found")
    end
  end

  describe "POST /api/v1/books" do
    let!(:author) { create(:author, name: "Jane Austen") }
    let(:params) { { book: { serial_number: "000123", title: "Emma", author_id: author.id } } }

    it "creates a book" do
      expect { post "/api/v1/books", params: params, as: :json }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to eq("serial_number" => "000123", "title" => "Emma",
                         "author_id" => author.id, "author" => "Jane Austen",
                         "status" => "available", "due_date" => nil)
      expect(Book.last.author).to eq(author)
    end

    it "returns validation errors for invalid data" do
      post "/api/v1/books", params: { book: { serial_number: "12", title: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "message")).to eq("Validation failed")
      expect(json.dig("error", "details")).to include("serial_number" => [ "must be exactly six digits" ],
                                        "title" => [ "can't be blank" ],
                                        "author_id" => [ "can't be blank" ])
    end

    it "rejects a duplicate serial number" do
      create(:book, serial_number: "000123")

      expect { post "/api/v1/books", params: params, as: :json }.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "serial_number")).to include("has already been taken")
    end

    it "refuses an author id that doesn't exist" do
      expect do
        post "/api/v1/books", params: { book: params[:book].merge(author_id: author.id + 1) }, as: :json
      end.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("author_id" => [ "doesn't match any author" ])
    end

    it "accepts the author id only as a JSON integer" do
      [ author.id.to_s, author.id.to_f, [ author.id ], { "id" => author.id } ].each do |author_id|
        expect do
          post "/api/v1/books", params: { book: params[:book].merge(author_id: author_id) }, as: :json
        end.not_to change(Book, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details")).to eq("author_id" => [ "must be an integer" ])
      end
    end

    it "rejects a title that is too long" do
      post "/api/v1/books", params: { book: params[:book].merge(title: "a" * 256) }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("title" => [ "is too long (maximum is 255 characters)" ])
    end

    it "rejects values that are not strings instead of converting or dropping them" do
      expect do
        post "/api/v1/books", params: { book: { serial_number: 123_456, title: [ "Emma" ],
                                                author_id: author.id } }, as: :json
      end.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("serial_number" => [ "must be a string" ],
                                                 "title" => [ "must be a string" ])
    end

    it "returns 400 for a request body that is not valid JSON" do
      post "/api/v1/books", params: '{"book": {"title": ', headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => { "message" => "Request body is not valid JSON" })
    end

    it "returns 400 when the book parameters are missing" do
      post "/api/v1/books", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "message")).to be_present
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    let!(:book) { create(:book, serial_number: "000123") }

    it "marks the book as deleted, keeping it in the database" do
      expect { delete "/api/v1/books/000123" }.not_to change(Book, :count)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(book.reload).to be_deleted
    end

    it "keeps the borrowing history of a deleted book" do
      reader = create(:reader, library_card_number: "100001")
      create(:borrow_record, :returned, book: book, reader: reader)

      expect { delete "/api/v1/books/000123" }.not_to change(BorrowRecord, :count)

      expect(response).to have_http_status(:no_content)
      get "/api/v1/readers/100001"
      expect(json["borrow_records"].map { it.dig("book", "serial_number") }).to eq([ "000123" ])
    end

    it "hides a deleted book from the API" do
      delete "/api/v1/books/000123"

      get "/api/v1/books"
      expect(json).to eq([])
      get "/api/v1/books/000123"
      expect(response).to have_http_status(:not_found)
      post "/api/v1/books/000123/borrow", params: { reader_card_number: create(:reader).library_card_number },
                                          as: :json
      expect(response).to have_http_status(:not_found)
      delete "/api/v1/books/000123"
      expect(response).to have_http_status(:not_found)
    end

    it "doesn't let a new book reuse a deleted book's serial number" do
      delete "/api/v1/books/000123"

      post "/api/v1/books", params: { book: { serial_number: "000123", title: "Emma",
                                              author_id: book.author_id } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "serial_number")).to eq([ "has already been taken" ])
    end

    it "refuses to delete a book that is currently borrowed" do
      create(:borrow_record, book: book)

      delete "/api/v1/books/000123"

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => { "message" => "Cannot delete a book that is currently borrowed" })
      expect(book.reload).not_to be_deleted
    end

    it "returns 404 for an unknown serial number" do
      delete "/api/v1/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "message")).to eq("Book not found")
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
      expect(json.dig("error", "message")).to eq("Book is already borrowed")
    end

    it "returns 422 for an unknown reader card number" do
      post "/api/v1/books/000123/borrow", params: { reader_card_number: "999999" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("reader_card_number" => [ "doesn't match any reader" ])
    end

    it "returns 422 when the reader card number is missing" do
      post "/api/v1/books/000123/borrow", params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("reader_card_number" => [ "can't be blank" ])
    end

    it "returns 422 when the reader card number is not a string" do
      [ 100_001, [ "000042" ], { "number" => "000042" }, true ].each do |card_number|
        expect do
          post "/api/v1/books/000123/borrow", params: { reader_card_number: card_number }, as: :json
        end.not_to change(BorrowRecord, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details")).to eq("reader_card_number" => [ "must be a string" ])
      end
    end

    it "returns 422 with the record's errors when the loan is invalid for another reason" do
      invalid_record = BorrowRecord.new.tap { it.errors.add(:due_date, "can't be blank") }
      allow(Borrowing).to receive(:borrow).and_raise(ActiveRecord::RecordInvalid, invalid_record)

      post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => { "message" => "Validation failed",
                                      "details" => { "due_date" => [ "can't be blank" ] } })
    end

    # The other cases (the model validation or the database index catching a loan made at the
    # same moment) are in spec/services/borrowing_spec.rb; they give the same answer.
    it "answers a conflict with the same status and message whichever check catches it" do
      allow(Borrowing).to receive(:borrow).and_raise(ConflictError, Borrowing::ALREADY_BORROWED)

      post "/api/v1/books/000123/borrow", params: { reader_card_number: "000042" }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => { "message" => "Book is already borrowed" })
    end

    it "returns 404 for an unknown serial number" do
      post "/api/v1/books/999999/borrow", params: { reader_card_number: "000042" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "message")).to eq("Book not found")
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
      expect(json.dig("error", "message")).to eq("Book is not borrowed")
    end

    it "returns 404 for an unknown serial number" do
      post "/api/v1/books/999999/return"

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "message")).to eq("Book not found")
    end
  end

  describe "unknown paths" do
    it "returns 404 in the API's error format" do
      get "/api/v1/publishers"

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => { "message" => "Not found" })
    end

    it "returns 404 for a method the path doesn't support" do
      patch "/api/v1/books/000123"

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "message")).to eq("Not found")
    end
  end
end
