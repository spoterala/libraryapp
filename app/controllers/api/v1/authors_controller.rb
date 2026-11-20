module Api
  module V1
    class AuthorsController < ApplicationController
      before_action :set_author, only: %i[show update destroy]

      # GET /api/v1/authors
      def index
        render json: AuthorResource.new(Author.order(:name, :id))
      end

      # GET /api/v1/authors/:id
      def show
        render json: AuthorDetailResource.new(@author)
      end

      # POST /api/v1/authors
      def create
        author = Author.new(author_params)

        if author.save
          render json: AuthorResource.new(author), status: :created
        else
          render_validation_errors(author)
        end
      end

      # PATCH /api/v1/authors/:id
      # Renames the author, e.g. to fix a misspelling. All their books show the new name.
      def update
        if @author.update(author_params)
          render json: AuthorResource.new(@author)
        else
          render_validation_errors(@author)
        end
      end

      # DELETE /api/v1/authors/:id
      # Not allowed while any book (even a deleted one) has this author
      def destroy
        if @author.destroy
          head :no_content
        else
          render_error("Cannot delete an author who has books", :conflict)
        end
      end

      private

      def set_author
        @author = Author.find(params[:id])
      end

      def author_params
        expect_typed_params(:author, name: String)
      end
    end
  end
end
