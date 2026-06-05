class PwaController < ApplicationController
  layout false

  skip_before_action :authenticate_user!

  def manifest
    render "pwa/manifest", formats: :json
  end
end
