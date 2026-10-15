require "net/smtp"
require "pagy"
require "pagy/classes/request"
require "pagy/toolbox/paginators/offset"

class ApplicationController < ActionController::Base
  include Pundit::Authorization

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

  rescue_from Pundit::NotAuthorizedError do
    redirect_to admin_root_path, alert: "You don't have permission to open that page."
  end

  private

  def pagy(collection, limit: 10, **options)
    pagy_request = Pagy::Request.new(
      { request: request, limit: limit }.merge(options)
    )

    Pagy::OffsetPaginator.paginate(collection, request: pagy_request)
  end

  def handle_mail_delivery_error(error)
    Rails.logger.error("Mail delivery failed: #{error.class} - #{error.message}")

    redirect_to new_user_password_path,
                alert: "We couldn't send the password reset email. Please check the Gmail app password settings."
  end

  def layout_by_resource
    devise_controller? ? "devise" : "admin"
  end
end
