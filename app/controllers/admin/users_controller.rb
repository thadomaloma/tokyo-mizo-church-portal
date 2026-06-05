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

      if @user.save
        notify("New Member Added", "#{current_user.name} added #{@user.name} as #{@user.role.humanize}.")
        redirect_to admin_users_path, notice: "Member was created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @user.update(user_params)
        notify("Member Updated", "#{current_user.name} updated #{@user.name}.")
        redirect_to admin_users_path, notice: "Member was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "Member was deleted."
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
        :role,
        :active,
        :password,
        :password_confirmation
      )
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
