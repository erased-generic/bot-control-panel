Rails.application.routes.draw do
  get 'dashboard', to: 'bot#dashboard'
  get 'status', to: 'bot#status'
  get 'logs', to: 'bot#logs'
  post 'control', to: 'bot#control', as: :control
  get "up" => "rails/health#show", as: :rails_health_check
end
