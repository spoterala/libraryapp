# Page-number pagination for list endpoints: ?page=2&per_page=20.
# Raises InvalidInputError (422) for a page or per_page that isn't a whole number in range.
#
#   pagination = Pagination.new(page: params[:page], per_page: params[:per_page])
#   records = pagination.apply(Book.kept.order(:serial_number))
#   pagination.meta # => { page: 2, per_page: 20, total_count: 45, total_pages: 3 }
class Pagination
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  attr_reader :page, :per_page

  # page and per_page are the raw query parameters (strings, or nil when not given)
  def initialize(page:, per_page:)
    errors = {}
    @page = parse(page, default: 1)
    errors[:page] = [ "must be a whole number of 1 or more" ] unless @page
    @per_page = parse(per_page, default: DEFAULT_PER_PAGE)
    errors[:per_page] = [ "must be a whole number from 1 to #{MAX_PER_PAGE}" ] unless @per_page&.<=(MAX_PER_PAGE)
    raise InvalidInputError, errors if errors.any?
  end

  # Returns this page's records of the (ordered) scope, and counts all of them for #meta.
  # A page after the last one is empty.
  def apply(scope)
    @total_count = scope.count
    offset = (page - 1) * per_page
    # Skips the query for a page past the end (also avoids a huge OFFSET for e.g. page=10**30)
    return scope.none if offset >= @total_count

    scope.offset(offset).limit(per_page)
  end

  def meta
    raise "call #apply first" unless @total_count

    { page: page, per_page: per_page, total_count: @total_count, total_pages: @total_count.fdiv(per_page).ceil }
  end

  private

  # A whole number of 1 or more, or nil if the value is anything else (0, "-1", "2.5", "abc", "", an array)
  def parse(value, default:)
    return default if value.nil?

    value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)
  end
end
