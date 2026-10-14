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

    resource :settings, only: :show
    resources :accounts, only: :index
    resources :offerings, only: %i[new create]
    get "budget(/:year)", to: "budgets#show", as: :budget, constraints: { year: /\d{4}/ }
    get "budget/:year/edit", to: "budgets#edit", as: :edit_budget, constraints: { year: /\d{4}/ }
    patch "budget/:year", to: "budgets#update", as: nil, constraints: { year: /\d{4}/ }

    resources :users, except: %i[index show]
    resources :finance_categories, only: :index
    resources :finance_transactions, except: :show do
      get :receipt, on: :member
    end
    get "finance_periods/:year/:month", to: "finance_periods#show", as: :finance_period, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    patch "finance_periods/:year/:month/close", to: "finance_periods#close", as: :close_finance_period, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    patch "finance_periods/:year/:month/reopen", to: "finance_periods#reopen", as: :reopen_finance_period, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    resources :finance_units, only: %i[index new create edit update] do
      resources :finance_unit_memberships, only: %i[create destroy]
    end
    resources :reports, only: [ :index ] do
      collection do
        get :finance
      end
    end
  end
end
