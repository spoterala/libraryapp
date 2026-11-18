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

  # JSON can send numbers, booleans, arrays or objects where text is expected. Rails would
  # silently turn them into text or drop them, so they're rejected with 422 instead.
  # Missing values and null are left to the model's presence validations.
  def require_string_values!(attributes, keys)
    details = keys.each_with_object({}) do |key, errors|
      value = attributes[key]
      errors[key] = [ "must be a string" ] unless value.nil? || value.is_a?(String)
    end
    raise InvalidInputError, details if details.any?
  end
end
