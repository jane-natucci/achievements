Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  scope path: "achievements" do
    root "achievements#index"
    get "help", to: "achievements#help"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"
    get "wizard", to: "wizard#profile", as: :wizard
    post "wizard", to: "wizard#create_profile"
    get "wizard/syncing", to: "wizard#syncing", as: :wizard_syncing
    get "wizard/sync_status", to: "wizard#sync_status", as: :wizard_sync_status
    get "wizard/game", to: "wizard#game", as: :wizard_game
    post "wizard/game", to: "wizard#set_game"
    get "wizard/achievements/:step", to: "wizard#achievement", as: :wizard_achievement, constraints: { step: /[1-3]/ }
    post "wizard/achievements/:step", to: "wizard#set_achievement", constraints: { step: /[1-3]/ }
    get "wizard/summary", to: "wizard#summary", as: :wizard_summary
    get "leaderboard", to: "users#index", as: :leaderboard
    get "users/:id", to: "users#show", as: :user
    resources :achievements
    resources :chains do
      member do
        post :favorite
        delete :favorite, action: :unfavorite
      end
    end
  end
end
