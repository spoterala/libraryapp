require "rails_helper"

RSpec.describe Pagination do
  def paginate(page: nil, per_page: nil) = described_class.new(page: page, per_page: per_page)

  it "defaults to page 1 with 20 per page" do
    expect(paginate).to have_attributes(page: 1, per_page: 20)
  end

  it "reads page and per_page from query parameter strings" do
    expect(paginate(page: "3", per_page: "100")).to have_attributes(page: 3, per_page: 100)
  end

  it "rejects values that aren't whole numbers in range" do
    [ "0", "-1", "1.5", "1e3", "abc", "", " 1", "01", 1, [ "1" ] ].each do |value|
      expect { paginate(page: value) }.to raise_error(InvalidInputError) { |error|
        expect(error.details).to eq(page: [ "must be a whole number of 1 or more" ])
      }
    end
    expect { paginate(per_page: "101") }.to raise_error(InvalidInputError) { |error|
      expect(error.details).to eq(per_page: [ "must be a whole number from 1 to 100" ])
    }
  end

  describe "#apply and #meta" do
    before { create_list(:author, 5) }

    let(:scope) { Author.order(:id) }

    it "returns one page of the scope and counts all records" do
      pagination = paginate(page: "2", per_page: "2")

      expect(pagination.apply(scope)).to eq(Author.order(:id).offset(2).first(2))
      expect(pagination.meta).to eq(page: 2, per_page: 2, total_count: 5, total_pages: 3)
    end

    it "returns no records past the last page, even for a huge page number" do
      pagination = paginate(page: (10**30).to_s)

      expect(pagination.apply(scope)).to be_empty
      expect(pagination.meta).to include(total_count: 5, total_pages: 1)
    end

    it "needs #apply before #meta" do
      expect { paginate.meta }.to raise_error(RuntimeError, "call #apply first")
    end
  end
end
