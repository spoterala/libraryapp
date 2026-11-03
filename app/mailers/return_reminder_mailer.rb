class ReturnReminderMailer < ApplicationMailer
  def due_soon(borrow_record)
    set_loan(borrow_record)
    @days_left = (@due_date - Date.current).to_i
    mail(to: @reader.email,
         subject: %(Reminder: "#{@book.title}" is due in #{@days_left} #{"day".pluralize(@days_left)}))
  end

  def due_today(borrow_record)
    set_loan(borrow_record)
    mail(to: @reader.email, subject: %(Reminder: "#{@book.title}" is due today))
  end

  private

  def set_loan(borrow_record)
    @reader = borrow_record.reader
    @book = borrow_record.book
    @due_date = borrow_record.due_date
  end
end
