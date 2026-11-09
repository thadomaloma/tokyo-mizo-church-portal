module Admin
  # "Change password" in Settings: anyone signed in can change their own,
  # after typing the current one.
  class PasswordsController < BaseController
    rate_limit to: 10, within: 15.minutes, only: :update,
               with: -> { redirect_to edit_admin_password_path, alert: "Too many tries. Please wait a few minutes and try again." }

    def edit; end

    def update
      # Devise treats a blank new password as "keep the current one".
      if password_params[:password].blank?
        current_user.errors.add(:password, :blank)
        render :edit, status: :unprocessable_entity
      elsif current_user.update_with_password(password_params)
        # Changing the password signs the user out everywhere else; stay signed in here.
        bypass_sign_in(current_user)
        redirect_to admin_settings_path, notice: "Password changed."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.expect(user: %i[current_password password password_confirmation])
    end
  end
end
