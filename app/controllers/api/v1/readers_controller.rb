module Api
  module V1
    class ReadersController < ApplicationController
      before_action :set_reader, only: %i[show destroy]

      # GET /api/v1/readers
      def index
        readers = Reader.order(:library_card_number)
        borrowed_counts = BorrowRecord.not_returned.group(:reader_id).count
        render json: readers.map { |reader|
          reader_json(reader).merge(borrowed_books_count: borrowed_counts.fetch(reader.id, 0))
        }
      end

      # GET /api/v1/readers/:library_card_number
      def show
        history = @reader.borrow_records.includes(:book).order(borrowed_date: :desc, id: :desc)
        render json: reader_json(@reader).merge(borrow_records: history.map { |record| history_json(record) })
      end

      # POST /api/v1/readers
      def create
        reader = Reader.new(reader_params)

        if reader.save
          render json: reader_json(reader), status: :created
        else
          render_validation_errors(reader)
        end
      end

      # DELETE /api/v1/readers/:library_card_number
      # Not allowed while the reader has any borrow records, so the borrowing history is kept
      def destroy
        if @reader.destroy
          head :no_content
        else
          render_error("Cannot delete a reader who has borrow records", :conflict)
        end
      end

      private

      def set_reader
        @reader = Reader.find_by!(library_card_number: params[:library_card_number])
      end

      def reader_params
        params.expect(reader: %i[library_card_number full_name email])
      end

      def reader_json(reader)
        reader.as_json(only: %i[library_card_number full_name email])
      end

      def history_json(record)
        {
          borrowed_date: record.borrowed_date,
          due_date: record.due_date,
          return_date: record.return_date,
          book: record.book.as_json(only: %i[serial_number title author])
        }
      end
    end
  end
end
