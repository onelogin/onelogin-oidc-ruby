Rails.application.routes.draw do
  post "login", to: "sessions#create", as: "new_session"
  delete "logout", to: "sessions#destroy", as: "destroy_session"

  get "dashboard", to: "dashboard#index"

  root "home#index"
end
