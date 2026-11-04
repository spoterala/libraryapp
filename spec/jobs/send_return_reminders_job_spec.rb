require "rails_helper"

RSpec.describe SendReturnRemindersJob, type: :job do
  include ActiveJob::TestHelper # perform_enqueued_jobs

  around { |example| travel_to(Time.zone.local(2026, 11, 10, 8)) { example.run } }

  def loan_due_in(days, **attributes)
    due_date = Date.current + days
    create(:borrow_record, borrowed_date: due_date - 30, due_date: due_date, **attributes)
  end

  it "runs every day at 8:00 Warsaw time" do
    schedule = Rails.application.config_for(:recurring, env: "development")[:send_return_reminders]

    expect(schedule).to eq(class: "SendReturnRemindersJob", schedule: "every day at 8am Europe/Warsaw")
  end

  it "queues a due-soon email for a loan due in 3 days and marks it as sent" do
    record = loan_due_in(3)

    expect { described_class.perform_now }
      .to have_enqueued_mail(ReturnReminderMailer, :due_soon).with(record).exactly(:once)

    expect(record.reload.due_soon_reminder_sent_at).to eq(Time.current)
    expect(record.due_today_reminder_sent_at).to be_nil
  end

  it "queues a due-today email for a loan due today and marks it as sent" do
    record = loan_due_in(0)

    expect { described_class.perform_now }
      .to have_enqueued_mail(ReturnReminderMailer, :due_today).with(record).exactly(:once)

    expect(record.reload.due_today_reminder_sent_at).to eq(Time.current)
  end

  it "sends nothing for returned loans or loans not due soon" do
    loan_due_in(3, return_date: Date.current)
    loan_due_in(10)

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "sends each reminder only once, even if the job runs again" do
    loan_due_in(3)
    loan_due_in(0)
    described_class.perform_now

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "sends the due-soon reminder 3 days before and the due-today one on the day" do
    record = loan_due_in(3)

    expect { described_class.perform_now }.to have_enqueued_mail(ReturnReminderMailer, :due_soon)

    travel 1.day
    expect { described_class.perform_now }.not_to have_enqueued_mail

    travel 2.days
    expect { described_class.perform_now }.to have_enqueued_mail(ReturnReminderMailer, :due_today).with(record)
  end

  it "skips a loan that another run marked in the meantime" do
    record = loan_due_in(3)
    # Another run marks the loan after this run has already found it
    allow(BorrowRecord).to receive(:needing_due_soon_reminder).and_wrap_original do |original|
      found = original.call.to_a
      record.update!(due_soon_reminder_sent_at: 1.minute.ago)
      BorrowRecord.where(id: found.map(&:id))
    end

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "delivers the queued email" do
    loan_due_in(3)

    perform_enqueued_jobs { described_class.perform_now }

    expect(ActionMailer::Base.deliveries.map(&:subject)).to contain_exactly(match(/is due in 3 days/))
  end

  it "doesn't deliver a queued email if the book is returned before it goes out" do
    record = loan_due_in(3)
    described_class.perform_now
    record.mark_returned!

    perform_enqueued_jobs

    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
