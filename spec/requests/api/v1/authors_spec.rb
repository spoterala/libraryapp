require "rails_helper"

RSpec.describe "Authors API", type: :request do
  let(:json) { response.parsed_body }

  describe "GET /api/v1/authors" do
    it "returns an empty list when there are no authors" do
      get "/api/v1/authors"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end

    it "lists authors ordered by name" do
      austen = create(:author, name: "Jane Austen")
      gaskell = create(:author, name: "Elizabeth Gaskell")

      get "/api/v1/authors"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([
        { "id" => gaskell.id, "name" => "Elizabeth Gaskell" },
        { "id" => austen.id, "name" => "Jane Austen" }
      ])
    end
  end

  describe "GET /api/v1/authors/:id" do
    let!(:author) { create(:author, name: "Jane Austen") }

    it "returns an author with no books" do
      get "/api/v1/authors/#{author.id}"

      expect(response).to have_http_status(:ok)
      expect(json).to eq("id" => author.id, "name" => "Jane Austen", "books" => [])
    end

    it "lists the author's books by title, with their availability, without deleted ones" do
      create(:book, author: author, serial_number: "000002", title: "Pride and Prejudice")
      emma = create(:book, author: author, serial_number: "000001", title: "Emma")
      create(:book, author: author, serial_number: "000003", title: "Persuasion").soft_delete
      create(:book, title: "North and South")
      loan = create(:borrow_record, book: emma)

      get "/api/v1/authors/#{author.id}"

      expect(json["books"]).to eq([
        { "serial_number" => "000001", "title" => "Emma", "author_id" => author.id, "author" => "Jane Austen",
          "status" => "borrowed", "due_date" => loan.due_date.iso8601 },
        { "serial_number" => "000002", "title" => "Pride and Prejudice", "author_id" => author.id,
          "author" => "Jane Austen", "status" => "available", "due_date" => nil }
      ])
    end

    it "returns 404 for an unknown id" do
      get "/api/v1/authors/#{author.id + 1}"

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => { "message" => "Author not found" })
    end

    it "returns 404 for an id that is not a number" do
      get "/api/v1/authors/#{author.id}abc"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/authors" do
    it "creates an author, storing the name without extra spaces" do
      expect do
        post "/api/v1/authors", params: { author: { name: "  Stanisław   Lem " } }, as: :json
      end.to change(Author, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to eq("id" => Author.last.id, "name" => "Stanisław Lem")
    end

    it "rejects a name that already exists in a different letter case" do
      create(:author, name: "Jane Austen")

      expect { post "/api/v1/authors", params: { author: { name: "JANE AUSTEN" } }, as: :json }
        .not_to change(Author, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("name" => [ "has already been taken" ])
    end

    it "returns validation errors for a missing name" do
      post "/api/v1/authors", params: { author: { name: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => { "message" => "Validation failed",
                                      "details" => { "name" => [ "can't be blank" ] } })
    end

    it "returns validation errors for a name that is too long" do
      post "/api/v1/authors", params: { author: { name: "a" * 256 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("name" => [ "is too long (maximum is 255 characters)" ])
    end

    it "rejects a name that is not a string" do
      post "/api/v1/authors", params: { author: { name: [ "Jane Austen" ] } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("name" => [ "must be a string" ])
    end

    it "returns 400 when the author parameters are missing" do
      post "/api/v1/authors", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "message")).to be_present
    end
  end

  describe "DELETE /api/v1/authors/:id" do
    let!(:author) { create(:author, name: "Jane Austen") }

    it "deletes an author with no books" do
      expect { delete "/api/v1/authors/#{author.id}" }.to change(Author, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it "refuses to delete an author who has books, even deleted ones" do
      create(:book, author: author).soft_delete

      expect { delete "/api/v1/authors/#{author.id}" }.not_to change(Author, :count)

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => { "message" => "Cannot delete an author who has books" })
    end

    it "returns 404 for an unknown id" do
      delete "/api/v1/authors/#{author.id + 1}"

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "message")).to eq("Author not found")
    end
  end
end
