class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error("#{error.model || 'Record'} not found", :not_found)
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(error.message, :bad_request)
  end

  # A database unique index rejected the change, e.g. two requests borrowing the same book at once
  rescue_from ActiveRecord::RecordNotUnique do
    render_error("Conflicts with an existing record", :conflict)
  end

  private

  def render_error(message, status)
    render json: { error: message }, status: status
  end

  def render_validation_errors(record)
    render json: { errors: record.errors.to_hash }, status: :unprocessable_content
  end
end
