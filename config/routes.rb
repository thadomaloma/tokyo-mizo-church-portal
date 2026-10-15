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
    resources :budgets, param: :year, only: %i[index show edit update], constraints: { year: /\d{4}/ }

    resources :users, except: %i[index show]
    resources :finance_categories, only: :index
    resources :finance_transactions, except: :show do
      resource :voucher, only: :show, module: :finance_transactions
    end
    scope "finance_periods/:year/:month", constraints: { year: /\d{4}/, month: /\d{1,2}/ } do
      get "/", to: "finance_periods#show", as: :finance_period
      resource :closure, only: %i[create destroy], module: :finance_periods, as: :finance_period_closure
    end
    resources :finance_units, only: %i[index new create edit update] do
      resources :finance_unit_memberships, only: %i[create destroy]
    end
    resource :finance_report, only: :show
  end
end
