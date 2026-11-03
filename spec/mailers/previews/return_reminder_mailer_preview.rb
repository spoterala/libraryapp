# Preview at http://localhost:3000/rails/mailers/return_reminder_mailer
# Uses a borrowed book from the database (e.g. from the seeds), or example data if there is none.
class ReturnReminderMailerPreview < ActionMailer::Preview
  def due_soon
    ReturnReminderMailer.due_soon(loan(due_in_days: BorrowRecord::DUE_SOON_REMINDER_DAYS))
  end

  def due_today
    ReturnReminderMailer.due_today(loan(due_in_days: 0))
  end

  private

  # The due date is changed in memory only, so the preview shows the right wording
  def loan(due_in_days:)
    record = BorrowRecord.not_returned.includes(:reader, :book).first || example_loan
    record.due_date = Date.current + due_in_days
    record
  end

  def example_loan
    BorrowRecord.new(reader: Reader.new(full_name: "Elizabeth Bennet", email: "elizabeth.bennet@example.com"),
                     book: Book.new(title: "Pride and Prejudice", author: "Jane Austen"))
  end
end
