require "rails_helper"

RSpec.describe ReturnReminderMailer, type: :mailer do
  around { |example| travel_to(Time.zone.local(2026, 11, 10, 8)) { example.run } }

  let(:reader) { create(:reader, full_name: "Elizabeth Bennet", email: "elizabeth.bennet@example.com") }
  let(:book) { create(:book, title: "Pride and Prejudice", author: "Jane Austen") }

  def loan_due_on(due_date)
    create(:borrow_record, reader: reader, book: book, borrowed_date: due_date - 30, due_date: due_date)
  end

  def bodies(mail)
    [ mail.text_part.body.to_s, mail.html_part.body.to_s ]
  end

  describe "#due_soon" do
    let(:mail) { described_class.due_soon(loan_due_on(Date.new(2026, 11, 13))) }

    it "is sent from the library to the reader" do
      expect(mail.from).to eq([ "library@example.com" ])
      expect(mail.to).to eq([ "elizabeth.bennet@example.com" ])
    end

    it "says how many days are left" do
      expect(mail.subject).to eq('Reminder: "Pride and Prejudice" is due in 3 days')
      bodies(mail).each { expect(it).to include("due in 3 days") }
    end

    it "includes the reader's name, the book and the due date in the text and HTML versions" do
      bodies(mail).each do |body|
        expect(body).to include("Elizabeth Bennet", "Pride and Prejudice", "Jane Austen", "November 13, 2026")
      end
    end

    it "uses the singular when one day is left (a missed reminder caught up)" do
      mail = described_class.due_soon(loan_due_on(Date.new(2026, 11, 11)))

      expect(mail.subject).to eq('Reminder: "Pride and Prejudice" is due in 1 day')
      expect(mail.text_part.body.to_s).to include("Due date: November 11, 2026")
    end
  end

  it "writes dates without a leading zero on the day (config/locales/en.yml)" do
    expect(I18n.l(Date.new(2026, 11, 6), format: :long)).to eq("November 6, 2026")
  end

  describe "#due_today" do
    let(:mail) { described_class.due_today(loan_due_on(Date.new(2026, 11, 10))) }

    it "is sent from the library to the reader" do
      expect(mail.from).to eq([ "library@example.com" ])
      expect(mail.to).to eq([ "elizabeth.bennet@example.com" ])
    end

    it "says the book is due today" do
      expect(mail.subject).to eq('Reminder: "Pride and Prejudice" is due today')
    end

    it "includes the reader's name, the book and the due date in the text and HTML versions" do
      bodies(mail).each do |body|
        expect(body).to include("Elizabeth Bennet", "Pride and Prejudice", "Jane Austen", "November 10, 2026")
      end
    end
  end
end
