class ApplicationController < ActionController::Base
  include Pundit::Authorization

  layout :layout_by_resource

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError do
    redirect_to admin_root_path, alert: "You are not authorized to access this page."
  end

  private

  def layout_by_resource
    devise_controller? ? "devise" : "admin"
  end
end
