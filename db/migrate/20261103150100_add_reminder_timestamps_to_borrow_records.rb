# When each return reminder was queued for a loan (empty = not sent yet), so it is sent only once
class AddReminderTimestampsToBorrowRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :borrow_records, :due_soon_reminder_sent_at, :datetime
    add_column :borrow_records, :due_today_reminder_sent_at, :datetime
  end
end
