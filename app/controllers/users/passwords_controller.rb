module Users
  # Password reset requests send email through the church Gmail account,
  # so they are capped per IP address to stop the form being used for spam.
  class PasswordsController < Devise::PasswordsController
    rate_limit to: 5, within: 15.minutes, only: :create,
               with: -> { redirect_to new_user_password_path, alert: "Too many reset requests. Please wait a few minutes and try again." }
  end
end
