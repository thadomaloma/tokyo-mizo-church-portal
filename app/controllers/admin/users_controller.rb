module Admin
  class UsersController < BaseController
    before_action :require_super_admin!, except: %i[index show]
    before_action :set_user, only: %i[show edit update destroy]

    def index
      @users = User.order(:role, :name)
    end

    def show; end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      role_assigned = assign_requested_role(@user)

      if role_assigned && @user.save
        notify("New Member Added", "#{current_user.name} added #{@user.name} as #{@user.role.humanize}.")
        redirect_to admin_users_path, notice: "Member was created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @user.assign_attributes(user_params)
      role_assigned = assign_requested_role(@user)

      if role_assigned && self_lockout_attempt?
        @user.errors.add(:base, "You cannot deactivate or remove administrator access from your own account.")
        render :edit, status: :unprocessable_entity
        return
      end

      if role_assigned && @user.save
        notify("Member Updated", "#{current_user.name} updated #{@user.name}.")
        redirect_to admin_users_path, notice: "Member was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
      elsif @user.destroy
        redirect_to admin_users_path, notice: "Member was deleted."
      else
        redirect_to admin_users_path,
                    alert: @user.errors.full_messages.to_sentence.presence || "Member could not be deleted."
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(
        :name,
        :email,
        :phone,
        :active,
        :password,
        :password_confirmation
      )
    end

    def assign_requested_role(user)
      role = params.dig(:user, :role).to_s
      unless User.roles.key?(role)
        user.errors.add(:role, "is not included in the approved roles")
        return false
      end

      user.role = role
      true
    end

    def self_lockout_attempt?
      @user == current_user && (!@user.active? || !@user.super_admin?)
    end

    def notify(title, message)
      NotificationCreator.call(
        actor: current_user,
        title: title,
        message: message,
        notification_type: "member",
        link: admin_users_path
      )
    end
  end
end
