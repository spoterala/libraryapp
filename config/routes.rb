Rails.application.routes.draw do
  # Health check: 200 when the app boots without errors (used by Docker's healthcheck)
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Books are identified by their serial number, e.g. /api/v1/books/000123
      resources :books, only: %i[index show create destroy], param: :serial_number do
        member do
          post :borrow
          post :return, action: :return_book
        end
      end

      # Readers are identified by their library card number, e.g. /api/v1/readers/100001
      resources :readers, only: %i[index show create destroy], param: :library_card_number
    end
  end
end
