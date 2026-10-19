module Users
  # Sign-in with a cap on attempts per IP address, so passwords cannot be
  # guessed at speed. Devise's lockable also locks an account after
  # repeated failures, whatever IP they come from.
  class SessionsController < Devise::SessionsController
    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to new_user_session_path, alert: "Too many sign-in attempts. Please wait a few minutes and try again." }
  end
end
