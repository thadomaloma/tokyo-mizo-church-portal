class PwaController < ApplicationController
  layout false

  skip_before_action :authenticate_user!
  skip_forgery_protection only: :service_worker

  def manifest
    render "pwa/manifest", formats: :json
  end

  def service_worker
    render "pwa/service-worker", formats: :js
  end
end
