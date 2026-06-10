Rails.application.routes.draw do
  get "manifest.json", to: "pwa#manifest", as: :pwa_manifest

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

    resources :notifications, only: [ :show ] do
      collection do
        patch :mark_all_as_read
      end
    end

    resources :users
    resources :finance_categories
    resources :finance_transactions do
      get :receipt, on: :member
    end
    resources :official_letters
    resources :official_letter_templates
    resources :meeting_minutes do
      get :new_archive, on: :collection
    end
    resources :church_resolutions do
      patch :mark_completed, on: :member
    end
    resources :church_events

    resources :reports, only: [ :index ] do
      collection do
        get :finance
        get :resolutions
        get :members
      end
    end
  end
end
