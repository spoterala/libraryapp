class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error("#{error.model || 'Record'} not found", :not_found)
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(error.message, :bad_request)
  end

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error("Request body is not valid JSON", :bad_request)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_validation_errors(error.record)
  end

  rescue_from InvalidInputError do |error|
    render_error(error.message, :unprocessable_content, details: error.details)
  end

  rescue_from ConflictError do |error|
    render_error(error.message, :conflict)
  end

  # A database unique index rejected the change, e.g. two requests adding the same reader at once
  rescue_from ActiveRecord::RecordNotUnique do
    render_error("Conflicts with an existing record", :conflict)
  end

  # Catch-all route (config/routes.rb)
  def route_not_found
    render_error("Not found", :not_found)
  end

  private

  def render_error(message, status, details: nil)
    error = { message: message }
    error[:details] = details if details
    render json: { error: error }, status: status
  end

  def render_validation_errors(record)
    render_error("Validation failed", :unprocessable_content, details: record.errors.to_hash)
  end

  TYPE_NAMES = { String => "a string", Integer => "an integer" }.freeze

  # params.expect(root => types.keys), checking that each value has its type, e.g.
  # expect_typed_params(:book, title: String, author_id: Integer). JSON can send another type than
  # expected (a number for a title, "4" or 4.5 for an id, an array or object anywhere); Rails would
  # silently convert or drop it, so it's rejected with 422 instead. This is checked first, because
  # dropping every value would look like missing parameters (400). Missing values and null are left
  # to the model's validations.
  def expect_typed_params(root, types)
    attributes = params[root]
    require_types!(attributes, types) if attributes.is_a?(ActionController::Parameters)
    params.expect(root => types.keys)
  end

  # A PATCH can't change the number used in the URL (a book's serial number, a reader's card
  # number). Sending the current value is fine, e.g. a client sending the whole record back; a
  # different value gets 422 instead of being silently ignored.
  def reject_identifier_change!(root, attribute, current_value)
    attributes = params[root]
    return unless attributes.is_a?(ActionController::Parameters) && attributes.key?(attribute)
    return if attributes[attribute] == current_value

    raise InvalidInputError, { attribute => [ "can't be changed" ] }
  end

  def require_types!(attributes, types)
    details = types.each_with_object({}) do |(key, type), errors|
      value = attributes[key]
      errors[key] = [ "must be #{TYPE_NAMES.fetch(type)}" ] unless value.nil? || value.is_a?(type)
    end
    raise InvalidInputError, details if details.any?
  end
end
