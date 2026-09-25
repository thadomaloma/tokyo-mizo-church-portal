Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest.json", to: "pwa#manifest", as: :pwa_manifest
  get "service-worker", to: "pwa#service_worker", as: :pwa_service_worker
  get "offline", to: "pwa#offline", as: :pwa_offline

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  devise_for :users, skip: [ :registrations ]

  authenticated :user do
    root "admin/dashboard#index", as: :authenticated_root
  end

  devise_scope :user do
    unauthenticated do
      root "devise/sessions#new"
    end
  end

  namespace :admin do
    root "dashboard#index"

    resources :notifications, only: %i[index show] do
      collection do
        patch :mark_all_as_read
      end
    end

    resource :profile, only: :show
    resource :push_subscription, only: %i[create destroy]

    resources :users
    resources :finance_categories, only: :index
    resources :finance_transactions, except: :show do
      get :receipt, on: :member
    end
    get "finance_periods/:year/:month", to: "finance_periods#show", as: :finance_period, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    patch "finance_periods/:year/:month/close", to: "finance_periods#close", as: :close_finance_period, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    patch "finance_periods/:year/:month/reopen", to: "finance_periods#reopen", as: :reopen_finance_period, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    resources :finance_units, only: :index do
      resources :finance_unit_memberships, only: %i[create destroy]
    end
    resources :meeting_minutes do
      get :new_archive, on: :collection
    end
    resources :church_resolutions do
      patch :mark_completed, on: :member
    end
    resources :official_letters
    resources :church_events

    resource :secretary_workspace, only: :show, controller: "secretary_workspace"

    resources :reports, only: [ :index ] do
      collection do
        get :finance
        get :resolutions
        get :members
      end
    end
  end
end
