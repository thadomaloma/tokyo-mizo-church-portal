require "net/smtp"

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  layout :layout_by_resource

  before_action :authenticate_user!

  rescue_from Net::SMTPAuthenticationError,
              Net::SMTPFatalError,
              Net::SMTPSyntaxError,
              Net::SMTPServerBusy,
              Net::SMTPUnknownError,
              OpenSSL::SSL::SSLError,
              with: :handle_mail_delivery_error

  rescue_from Pundit::NotAuthorizedError do
    redirect_to admin_root_path, alert: "You are not authorized to access this page."
  end

  private

  def handle_mail_delivery_error(error)
    Rails.logger.error("Mail delivery failed: #{error.class} - #{error.message}")

    redirect_to new_user_password_path,
                alert: "Password reset email could not be sent. Please check the Gmail app password settings."
  end

  def layout_by_resource
    devise_controller? ? "devise" : "admin"
  end
end
