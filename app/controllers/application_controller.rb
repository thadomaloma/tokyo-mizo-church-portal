require "net/smtp"

class ApplicationController < ActionController::Base
  include Pagy::Method

  layout :layout_by_resource

  before_action :authenticate_user!

  rescue_from Net::SMTPAuthenticationError,
              Net::SMTPFatalError,
              Net::SMTPSyntaxError,
              Net::SMTPServerBusy,
              Net::SMTPUnknownError,
              Net::OpenTimeout,
              Net::ReadTimeout,
              SocketError,
              OpenSSL::SSL::SSLError,
              with: :handle_mail_delivery_error

  private

  def handle_mail_delivery_error(error)
    Rails.logger.error("Mail delivery failed: #{error.class} - #{error.message}")

    redirect_to new_user_password_path,
                alert: "We couldn't send the password reset email. Please check the Gmail app password settings."
  end

  def layout_by_resource
    devise_controller? ? "devise" : "admin"
  end
end
