require "rails_helper"

# Every factory must produce a valid record, otherwise specs using it would fail
# for the wrong reason.
RSpec.describe "Factories" do
  FactoryBot.factories.map(&:name).each do |factory_name|
    it "builds a valid #{factory_name}" do
      expect(build(factory_name)).to be_valid
    end

    it "creates two #{factory_name} records without unique values clashing" do
      expect { create_pair(factory_name) }.not_to raise_error
    end
  end
end
