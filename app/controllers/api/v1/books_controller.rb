module Api
  module V1
    class BooksController < ApplicationController
      before_action :set_book, only: %i[show destroy borrow return_book]

      # GET /api/v1/books
      def index
        books = Book.includes(:current_borrow_record).order(:serial_number)
        render json: books.map { |book| book_json(book) }
      end

      # GET /api/v1/books/:serial_number
      def show
        history = @book.borrow_records.includes(:reader).order(borrowed_date: :desc, id: :desc)
        render json: book_json(@book).merge(borrow_records: history.map { |record| history_json(record) })
      end

      # POST /api/v1/books
      def create
        book = Book.new(book_params)

        if book.save
          render json: book_json(book), status: :created
        else
          render_validation_errors(book)
        end
      end

      # DELETE /api/v1/books/:serial_number
      def destroy
        if @book.destroy
          head :no_content
        else
          render_error(@book.errors.full_messages.to_sentence, :conflict)
        end
      end

      # POST /api/v1/books/:serial_number/borrow
      def borrow
        reader = Reader.find_by(library_card_number: params[:reader_card_number])
        unless reader
          return render json: { errors: { reader_card_number: [ "doesn't match any reader" ] } },
                        status: :unprocessable_content
        end
        return render_error("Book is already borrowed", :conflict) if @book.borrowed?

        record = @book.borrow_by(reader)
        if record.persisted?
          render json: borrow_record_json(record), status: :created
        else
          render_validation_errors(record)
        end
      end

      # POST /api/v1/books/:serial_number/return
      def return_book
        record = @book.current_borrow_record
        return render_error("Book is not borrowed", :conflict) unless record

        record.mark_returned!
        render json: borrow_record_json(record)
      end

      private

      def set_book
        @book = Book.find_by!(serial_number: params[:serial_number])
      end

      def book_params
        params.expect(book: %i[serial_number title author])
      end

      def book_json(book)
        loan = book.current_borrow_record
        {
          serial_number: book.serial_number,
          title: book.title,
          author: book.author,
          status: loan ? "borrowed" : "available",
          due_date: loan&.due_date
        }
      end

      # One loan in a book's history, with the reader's details
      def history_json(record)
        {
          borrowed_date: record.borrowed_date,
          due_date: record.due_date,
          return_date: record.return_date,
          reader: record.reader.as_json(only: %i[library_card_number full_name email])
        }
      end

      def borrow_record_json(record)
        record.as_json(only: %i[borrowed_date due_date return_date],
                       methods: %i[book_serial_number reader_card_number])
      end
    end
  end
end
