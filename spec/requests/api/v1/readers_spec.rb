require "rails_helper"

RSpec.describe "Readers API", type: :request do
  let(:json) { response.parsed_body }

  describe "GET /api/v1/readers" do
    it "returns an empty list when there are no readers" do
      get "/api/v1/readers"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end

    it "lists readers ordered by card number" do
      create(:reader, library_card_number: "100002", full_name: "Charlotte Lucas", email: "charlotte.lucas@example.com")
      create(:reader, library_card_number: "100001", full_name: "Elizabeth Bennet", email: "elizabeth.bennet@example.com")

      get "/api/v1/readers"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([
        { "library_card_number" => "100001", "full_name" => "Elizabeth Bennet", "email" => "elizabeth.bennet@example.com",
          "borrowed_books_count" => 0 },
        { "library_card_number" => "100002", "full_name" => "Charlotte Lucas", "email" => "charlotte.lucas@example.com",
          "borrowed_books_count" => 0 }
      ])
    end

    it "counts only the books each reader has not returned yet" do
      reader = create(:reader, library_card_number: "100001")
      other_reader = create(:reader, library_card_number: "100002")
      create_list(:borrow_record, 2, reader: reader)
      create(:borrow_record, :returned, reader: reader)
      create(:borrow_record, reader: other_reader)

      get "/api/v1/readers"

      expect(json.map { it.values_at("library_card_number", "borrowed_books_count") })
        .to eq([ [ "100001", 2 ], [ "100002", 1 ] ])
    end
  end

  describe "GET /api/v1/readers/:library_card_number" do
    let!(:reader) do
      create(:reader, library_card_number: "100001", full_name: "Elizabeth Bennet",
                      email: "elizabeth.bennet@example.com")
    end

    it "returns a reader with an empty history" do
      get "/api/v1/readers/100001"

      expect(response).to have_http_status(:ok)
      expect(json).to eq("library_card_number" => "100001", "full_name" => "Elizabeth Bennet",
                         "email" => "elizabeth.bennet@example.com", "borrow_records" => [])
    end

    it "returns the full borrowing history, newest first, with the books' details" do
      old_book = create(:book, serial_number: "000001", title: "Pride and Prejudice", author: "Jane Austen")
      new_book = create(:book, serial_number: "000002")
      create(:borrow_record, reader: reader, book: old_book,
                             borrowed_date: Date.new(2026, 5, 4), return_date: Date.new(2026, 5, 25))
      current = create(:borrow_record, reader: reader, book: new_book, borrowed_date: Date.current - 3)

      get "/api/v1/readers/100001"

      expect(response).to have_http_status(:ok)
      expect(json["borrow_records"]).to eq([
        { "borrowed_date" => (Date.current - 3).iso8601, "due_date" => current.due_date.iso8601,
          "return_date" => nil,
          "book" => { "serial_number" => "000002", "title" => new_book.title, "author" => new_book.author } },
        { "borrowed_date" => "2026-05-04", "due_date" => "2026-06-03", "return_date" => "2026-05-25",
          "book" => { "serial_number" => "000001", "title" => "Pride and Prejudice", "author" => "Jane Austen" } }
      ])
    end

    it "doesn't include other readers' loans" do
      create(:borrow_record, reader: create(:reader))

      get "/api/v1/readers/100001"

      expect(json["borrow_records"]).to eq([])
    end

    it "returns 404 for an unknown card number" do
      get "/api/v1/readers/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Reader not found")
    end
  end

  describe "POST /api/v1/readers" do
    let(:params) do
      { reader: { library_card_number: "100001", full_name: "Elizabeth Bennet",
                  email: "Elizabeth.Bennet@Example.com " } }
    end

    it "creates a reader, storing the email trimmed and lowercased" do
      expect { post "/api/v1/readers", params: params, as: :json }.to change(Reader, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to eq("library_card_number" => "100001", "full_name" => "Elizabeth Bennet",
                         "email" => "elizabeth.bennet@example.com")
    end

    it "returns validation errors for invalid data" do
      post "/api/v1/readers", params: { reader: { library_card_number: "12", email: "not-an-email" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to include("library_card_number" => [ "must be exactly six digits" ],
                                        "full_name" => [ "can't be blank" ],
                                        "email" => [ "is not a valid email address" ])
    end

    it "rejects a duplicate card number or email" do
      create(:reader, library_card_number: "100001", email: "elizabeth.bennet@example.com")

      expect { post "/api/v1/readers", params: params, as: :json }.not_to change(Reader, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to include("library_card_number" => [ "has already been taken" ],
                                        "email" => [ "has already been taken" ])
    end

    it "returns 400 when the reader parameters are missing" do
      post "/api/v1/readers", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to be_present
    end
  end

  describe "DELETE /api/v1/readers/:library_card_number" do
    let!(:reader) { create(:reader, library_card_number: "100001") }

    it "deletes a reader" do
      expect { delete "/api/v1/readers/100001" }.to change(Reader, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it "refuses to delete a reader who has borrow records, even returned ones" do
      create(:borrow_record, :returned, reader: reader)

      expect { delete "/api/v1/readers/100001" }.not_to change(Reader, :count)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq("Cannot delete a reader who has borrow records")
    end

    it "returns 404 for an unknown card number" do
      delete "/api/v1/readers/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Reader not found")
    end
  end
end
