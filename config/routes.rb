require "sidekiq/web"

# ECS injects SIDEKIQ_USERNAME/SIDEKIQ_PASSWORD as env vars sourced from
# SSM Parameter Store in production; local dev falls back to Rails
# credentials (config/credentials.yml.enc, key: sidekiq.username/password).
Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
  expected_username = ENV.fetch("SIDEKIQ_USERNAME") { Rails.application.credentials.dig(:sidekiq, :username) }
  expected_password = ENV.fetch("SIDEKIQ_PASSWORD") { Rails.application.credentials.dig(:sidekiq, :password) }

  ActiveSupport::SecurityUtils.secure_compare(username, expected_username) &&
    ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # True bare "/" shows the minimal welcome/landing page (the app itself
  # still lives under /achievements below; this doesn't use `root` so it
  # doesn't touch the existing root_path helper used throughout the app).
  get "/", to: "welcome#index"

  mount Sidekiq::Web => "/sidekiq"
  get "/debug", to: "debug#index"

  scope path: "achievements" do
    root "achievements#index"
    get "welcome", to: "welcome#index", as: :welcome
    get "help", to: "achievements#help"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    get "login/steam", to: "sessions#steam", as: :login_steam
    get "login/steam/callback", to: "sessions#steam_callback", as: :login_steam_callback
    delete "logout", to: "sessions#destroy"
    post "heartbeat", to: "sessions#heartbeat"
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
    get "users/:id/wall", to: "users#wall", as: :user_wall
    resources :comments, only: [:create, :destroy]
    resources :achievements do
      member do
        post :favorite
        delete :favorite, action: :unfavorite
        post :pin
        delete :pin, action: :unpin
      end
    end
    resources :chains do
      member do
        post :favorite
        delete :favorite, action: :unfavorite
      end
    end
    resources :battles, only: [:index, :new, :create, :show] do
      member do
        post :place
        post :attack
        post :end_turn
      end
    end
  end
end
