module Admin
  class BaseController < ApplicationController
    layout "admin"

    helper_method :available_finance_units,
                  :current_finance_unit,
                  :can_manage_current_finance_unit?,
                  :finance_access?

    before_action :ensure_active_user
    before_action :load_notifications

    private

    def load_notifications
      @notifications = Notification
                        .visible_for(current_user)
                        .latest
                        .includes(:notification_reads)
                        .limit(10)

      @notifications_count =
        Notification.unread_for(current_user).count
    end

    def ensure_active_user
      return if current_user&.active?

      sign_out current_user
      redirect_to new_user_session_path, alert: "I account hi hman theih lohva dah a ni."
    end

    def require_super_admin!
      return if current_user.super_admin?

      redirect_to admin_root_path,
                  alert: "President emaw Secretary chauhin he page hi an hmang thei."
    end

    def available_finance_units
      @available_finance_units ||= current_user.accessible_finance_units
    end

    def finance_access?
      current_user.finance_access?
    end

    def require_finance_access!
      return if finance_access?

      redirect_to admin_root_path,
                  alert: "I account-ah finance access pek a la ni lo."
    end

    def current_finance_unit
      @current_finance_unit ||= begin
        requested_id = params[:finance_unit_id].presence
        requested_id ? available_finance_units.find(requested_id) : preferred_accessible_finance_unit
      end
    end

    def preferred_accessible_finance_unit
      preferred = current_user.preferred_finance_unit
      return unless preferred

      available_finance_units.find_by(id: preferred.id) || available_finance_units.first
    end

    def can_manage_current_finance_unit?
      current_finance_unit.present? && current_user.can_manage_finance_unit?(current_finance_unit)
    end

    def require_finance_unit_manager!
      return if can_manage_current_finance_unit?

      redirect_to admin_finance_transactions_path(finance_unit_id: current_finance_unit&.id),
                  alert: "He finance unit enkawl phalna i nei lo."
    end
  end
end
