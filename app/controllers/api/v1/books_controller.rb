module Api
  module V1
    class BooksController < ApplicationController
      before_action :set_book, only: %i[show destroy borrow return_book]

      # GET /api/v1/books
      def index
        books = Book.kept.includes(:author, :current_borrow_record).order(:serial_number)
        render json: BookResource.new(books)
      end

      # GET /api/v1/books/:serial_number
      def show
        render json: BookDetailResource.new(@book)
      end

      # POST /api/v1/books
      def create
        book = Book.new(book_params)

        if book.save
          render json: BookResource.new(book), status: :created
        else
          render_validation_errors(book)
        end
      end

      # DELETE /api/v1/books/:serial_number
      # The book is only marked as deleted, so its borrowing history is kept
      def destroy
        if @book.soft_delete
          head :no_content
        else
          render_error(@book.errors.full_messages.to_sentence, :conflict)
        end
      end

      # POST /api/v1/books/:serial_number/borrow
      def borrow
        record = Borrowing.borrow(@book, reader_card_number: params[:reader_card_number])
        render json: BorrowRecordResource.new(record), status: :created
      end

      # POST /api/v1/books/:serial_number/return
      def return_book
        record = Borrowing.return_book(@book)
        render json: BorrowRecordResource.new(record)
      end

      private

      def set_book
        @book = Book.kept.find_by!(serial_number: params[:serial_number])
      end

      def book_params
        expect_typed_params(:book, serial_number: String, title: String, author_id: Integer)
      end
    end
  end
end
