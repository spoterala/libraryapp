module Api
  module V1
    class ReadersController < ApplicationController
      READER_ATTRIBUTES = %i[library_card_number full_name email].freeze

      before_action :set_reader, only: %i[show destroy]

      # GET /api/v1/readers
      def index
        readers = Reader.order(:library_card_number)
        borrowed_counts = BorrowRecord.not_returned.group(:reader_id).count
        render json: ReaderListResource.new(readers, params: { borrowed_counts: borrowed_counts })
      end

      # GET /api/v1/readers/:library_card_number
      def show
        render json: ReaderDetailResource.new(@reader)
      end

      # POST /api/v1/readers
      def create
        reader = Reader.new(reader_params)

        if reader.save
          render json: ReaderResource.new(reader), status: :created
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
        permitted = params.expect(reader: READER_ATTRIBUTES)
        require_string_values!(params[:reader], READER_ATTRIBUTES)
        permitted
      end
    end
  end
end
