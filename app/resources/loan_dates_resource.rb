# The dates of a borrow record, shared by the loan resources
class LoanDatesResource
  include Alba::Resource

  attributes :borrowed_date, :due_date, :return_date
end
