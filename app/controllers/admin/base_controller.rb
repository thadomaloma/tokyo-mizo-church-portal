module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :ensure_active_user
    before_action :load_notifications

    private

    def load_notifications
      @notifications = Notification
                        .visible_for(current_user)
                        .latest
                        .limit(10)

      @notifications_count =
        Notification.unread_for(current_user).count
    end

    def ensure_active_user
      return if current_user&.active?

      sign_out current_user
      redirect_to new_user_session_path, alert: "Your account is inactive."
    end

    def require_super_admin!
      return if current_user.super_admin?

      redirect_to admin_root_path,
                  alert: "Only President or Secretary can access this page."
    end

    def require_finance_admin!
      return if current_user.super_admin? || current_user.finance_admin?

      redirect_to admin_root_path,
                  alert: "Finance access is restricted."
    end
  end
end
