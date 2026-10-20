Rails.application.routes.draw do
  get "login", to: "sessions#new", as: "new_session"
  get "signin-oidc", to: "sessions#callback", as: "session_callback"
  delete "logout", to: "sessions#destroy", as: "destroy_session"

  get "dashboard", to: "dashboard#index"

  root "home#index"
end
