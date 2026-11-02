# Lets specs call build(:book), create(:reader) etc. without the FactoryBot. prefix
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
