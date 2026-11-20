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
      old_book = create(:book, serial_number: "000001", title: "Pride and Prejudice",
                                  author: create(:author, name: "Jane Austen"))
      new_book = create(:book, serial_number: "000002")
      create(:borrow_record, reader: reader, book: old_book,
                             borrowed_date: Date.new(2026, 5, 4), return_date: Date.new(2026, 5, 25))
      current = create(:borrow_record, reader: reader, book: new_book, borrowed_date: Date.current - 3)

      get "/api/v1/readers/100001"

      expect(response).to have_http_status(:ok)
      expect(json["borrow_records"]).to eq([
        { "borrowed_date" => (Date.current - 3).iso8601, "due_date" => current.due_date.iso8601,
          "return_date" => nil,
          "book" => { "serial_number" => "000002", "title" => new_book.title,
                      "author_id" => new_book.author_id, "author" => new_book.author.name } },
        { "borrowed_date" => "2026-05-04", "due_date" => "2026-06-03", "return_date" => "2026-05-25",
          "book" => { "serial_number" => "000001", "title" => "Pride and Prejudice",
                      "author_id" => old_book.author_id, "author" => "Jane Austen" } }
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
      expect(json.dig("error", "message")).to eq("Reader not found")
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
      expect(json.dig("error", "details")).to include("library_card_number" => [ "must be exactly six digits" ],
                                        "full_name" => [ "can't be blank" ],
                                        "email" => [ "is not a valid email address" ])
    end

    it "rejects a duplicate card number or email" do
      create(:reader, library_card_number: "100001", email: "elizabeth.bennet@example.com")

      expect { post "/api/v1/readers", params: params, as: :json }.not_to change(Reader, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to include("library_card_number" => [ "has already been taken" ],
                                        "email" => [ "has already been taken" ])
    end

    it "rejects a name or email that is too long" do
      post "/api/v1/readers", params: { reader: params[:reader].merge(full_name: "a" * 256,
                                                                      email: "#{'a' * 243}@example.com") },
                              as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to include("full_name" => [ "is too long (maximum is 255 characters)" ])
      expect(json.dig("error", "details", "email")).to include("is too long (maximum is 254 characters)")
    end

    it "rejects values that are not strings instead of converting them" do
      expect do
        post "/api/v1/readers", params: { reader: { library_card_number: 100_001, full_name: false,
                                                    email: [ "elizabeth.bennet@example.com" ] } }, as: :json
      end.not_to change(Reader, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("library_card_number" => [ "must be a string" ],
                                                 "full_name" => [ "must be a string" ],
                                                 "email" => [ "must be a string" ])
    end

    it "returns 409 when the database catches a duplicate the validation missed" do
      # e.g. two requests adding the same reader at the same moment
      allow_any_instance_of(Reader).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post "/api/v1/readers", params: params, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => { "message" => "Conflicts with an existing record" })
    end

    it "returns 400 when the reader parameters are not an object" do
      post "/api/v1/readers", params: { reader: "Elizabeth Bennet" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when the reader parameters are missing" do
      post "/api/v1/readers", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "message")).to be_present
    end
  end

  describe "PATCH /api/v1/readers/:library_card_number" do
    let!(:reader) do
      create(:reader, library_card_number: "100001", full_name: "Elizabeth Bennet",
                      email: "elizabeth.bennet@example.com")
    end

    it "changes the name and the email, storing the email trimmed and lowercased" do
      patch "/api/v1/readers/100001",
            params: { reader: { full_name: "Elizabeth Darcy", email: " Elizabeth.Darcy@Example.com" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq("library_card_number" => "100001", "full_name" => "Elizabeth Darcy",
                         "email" => "elizabeth.darcy@example.com")
      expect(reader.reload).to have_attributes(full_name: "Elizabeth Darcy", email: "elizabeth.darcy@example.com")
    end

    it "changes only the fields that are sent" do
      patch "/api/v1/readers/100001", params: { reader: { email: "lizzy@example.com" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("full_name" => "Elizabeth Bennet", "email" => "lizzy@example.com")
    end

    it "accepts the current card number, e.g. when the whole reader is sent back" do
      patch "/api/v1/readers/100001",
            params: { reader: { library_card_number: "100001", full_name: "Elizabeth Darcy" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(reader.reload.full_name).to eq("Elizabeth Darcy")
    end

    it "refuses to change the card number" do
      patch "/api/v1/readers/100001", params: { reader: { library_card_number: "100002" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("library_card_number" => [ "can't be changed" ])
      expect(reader.reload.library_card_number).to eq("100001")
    end

    it "returns validation errors for invalid data" do
      patch "/api/v1/readers/100001", params: { reader: { full_name: "", email: "not-an-email" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("full_name" => [ "can't be blank" ],
                                                 "email" => [ "is not a valid email address" ])
      expect(reader.reload.full_name).to eq("Elizabeth Bennet")
    end

    it "rejects an email that another reader already has" do
      create(:reader, email: "jane.bennet@example.com")

      patch "/api/v1/readers/100001", params: { reader: { email: "Jane.Bennet@example.com" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("email" => [ "has already been taken" ])
    end

    it "rejects values that are not strings" do
      patch "/api/v1/readers/100001", params: { reader: { full_name: [ "Lizzy" ], email: 1 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("full_name" => [ "must be a string" ],
                                                 "email" => [ "must be a string" ])
    end

    it "returns 409 when the database catches a duplicate the validation missed" do
      allow_any_instance_of(Reader).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)

      patch "/api/v1/readers/100001", params: { reader: { email: "lizzy@example.com" } }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => { "message" => "Conflicts with an existing record" })
    end

    it "returns 400 when there is nothing to change" do
      [ {}, { reader: {} }, { reader: { phone: "123" } } ].each do |params|
        patch "/api/v1/readers/100001", params: params, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    it "returns 404 for an unknown card number" do
      patch "/api/v1/readers/999999", params: { reader: { full_name: "Nobody" } }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => { "message" => "Reader not found" })
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
      expect(json.dig("error", "message")).to eq("Cannot delete a reader who has borrow records")
    end

    it "returns 404 for an unknown card number" do
      delete "/api/v1/readers/999999"

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "message")).to eq("Reader not found")
    end
  end
end
