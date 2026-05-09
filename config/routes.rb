Rails.application.routes.draw do
  resource :registration, only: %i[ new create ], controller: :registrations, path: :registro
  resource :session, only: %i[ new create destroy ], path: :sesion
  resources :passwords, only: %i[ new create edit update ], param: :token, path: :acceso

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"
  get :manual, to: "manual#show", as: :manual

  get :panel, to: "dashboard#show", as: :dashboard
  resource :profile, only: %i[ edit update ], path: :perfil
  resources :inventory_items, only: %i[ create update destroy ], path: :inventario
  get :mercado, to: "matches#index", as: :matches
  resources :swap_offers, only: %i[ index create ], path: :intercambios
  patch "intercambios/:id/aceptar", to: "swap_offers#accept", as: :accept_swap_offer
  patch "intercambios/:id/rechazar", to: "swap_offers#decline", as: :decline_swap_offer
end
