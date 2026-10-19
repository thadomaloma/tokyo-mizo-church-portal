module Admin
  class UsersController < BaseController
    before_action :require_super_admin!
    before_action :set_user, only: %i[edit update destroy]

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_settings_path, notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @user.assign_attributes(user_params)

      if self_lockout_attempt?
        @user.errors.add(:base, "You can't deactivate your own account or remove your own admin access.")
        render :edit, status: :unprocessable_entity
        return
      end

      if @user.save
        # Saving a locked-out user (often with a new password) unlocks them.
        @user.unlock_access! if @user.access_locked?
        redirect_to admin_settings_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_settings_path, alert: "You can't delete your own account."
      elsif @user.destroy
        redirect_to admin_settings_path, notice: "User deleted."
      else
        redirect_to admin_settings_path,
                    alert: @user.errors.full_messages.to_sentence.presence || "This user can't be deleted."
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: %i[name email phone role active password password_confirmation])
    end

    def self_lockout_attempt?
      @user == current_user && (!@user.active? || !@user.super_admin?)
    end
  end
end
