Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    confirmations: "users/confirmations",
    sessions: "users/sessions",
    passwords: "users/passwords"
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Forms validation
  post "forms/validate", to: "forms#validate", as: :validate_form

  # Pages
  get "home", to: "pages#home"
  get "home/feed", to: "pages#feed", as: :home_feed

  # User Profiles
  get "/profiles/:username", to: "profiles#show", as: :profile
  # Follows (one-way): follow / unfollow, and the lists on a profile
  get "/profiles/:username/follow", to: "profiles#show", as: :follow_profile
  post "/profiles/:username/follow", to: "profiles#create"
  delete "/profiles/:username/follow", to: "profiles#destroy"
  get "/profiles/:username/followers", to: "profiles#followers", as: :profile_followers
  get "/profiles/:username/following", to: "profiles#following", as: :profile_following
  get "/profiles/:username/edit", to: "profiles#edit", as: :edit_profile
  patch "/profiles/:username", to: "profiles#update"
  put "/profiles/:username", to: "profiles#update"

  # Users
  match "users/search", to: "users#search", as: :search_users, via: [ :get, :post ]
  get "users/:id", to: "users#show", as: :user

  # Posts with nested comments, likes, and reactions
  resources :posts do
    resources :comments, only: [ :create, :destroy ]
    resources :likes, only: [ :create, :destroy ]
    resources :reactions, only: [ :index, :create, :destroy ]
    member do
      patch :publish
    end
  end
  post "posts/save-draft", to: "posts#save_draft", as: :save_draft_post
  get "my-drafts", to: "posts#drafts", as: :drafts_posts

  # Old friend pages (replaced by follows): bookmarks open the user's Following list
  get "friendships", to: "follows#mine"
  get "friend-requests", to: "follows#mine"

  # Messages (under construction)
  get "messages", to: "messages#index", as: :messages

  # Notifications
  resources :notifications, only: [ :index, :destroy ]
  patch "notifications/:id/mark-as-read", to: "notifications#mark_as_read", as: :mark_notification_as_read
  patch "notifications/mark-all-as-read", to: "notifications#mark_all_as_read", as: :mark_all_notifications_as_read

  # Polling API endpoints for Vercel deployment
  namespace :notifications do
    get :polling, defaults: { format: :json }
    post :polling, to: :refresh, defaults: { format: :json }
  end

  # Defines the root path route ("/")
  root "pages#home"
end