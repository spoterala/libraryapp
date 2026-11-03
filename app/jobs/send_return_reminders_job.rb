# Runs every morning (config/recurring.yml). Queues a "due soon" or "due today" email for each
# open loan that needs one, and records that it was sent so it never goes out twice.
class SendReturnRemindersJob < ApplicationJob
  queue_as :default

  def perform
    send_reminders(BorrowRecord.needing_due_soon_reminder, :due_soon, :due_soon_reminder_sent_at)
    send_reminders(BorrowRecord.needing_due_today_reminder, :due_today, :due_today_reminder_sent_at)
  end

  private

  def send_reminders(records, email, sent_at_column)
    records.find_each do |record|
      BorrowRecord.transaction do
        claimed = BorrowRecord.where(id: record.id, sent_at_column => nil)
                              .update_all(sent_at_column => Time.current, updated_at: Time.current)
        ReturnReminderMailer.public_send(email, record).deliver_later if claimed == 1
      end
    end
  end
end
