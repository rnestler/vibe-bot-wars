# frozen_string_literal: true

Rails.application.routes.draw do
  # Live arena (the home page).
  root "arena#show"

  # Registered bots: name + webhook URL. `test` probes the webhook once.
  resources :bots do
    member { post :test }
  end

  # Match lifecycle: start (new match, resets the arena) and stop.
  post "match/start" => "matches#create", as: :start_match
  post "match/stop" => "matches#stop", as: :stop_match

  # Built-in sample bot so a match can run end-to-end without any external server.
  post "demo_bot" => "demo_bot#respond", as: :demo_bot

  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
