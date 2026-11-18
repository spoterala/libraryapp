# The request's input is invalid. `details` maps each field to its messages, like
# ActiveModel errors: { reader_card_number: ["can't be blank"] }. The API answers 422.
class InvalidInputError < StandardError
  attr_reader :details

  def initialize(details)
    @details = details
    super("Validation failed")
  end
end
