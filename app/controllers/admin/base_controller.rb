module Admin
  class BaseController < ApplicationController
    layout "admin"

    helper_method :available_finance_units, :current_finance_unit, :finance_access?

    before_action :ensure_active_user

    private

    def ensure_active_user
      return if current_user&.active?

      sign_out current_user
      redirect_to new_user_session_path, alert: "Your account has been deactivated."
    end

    def require_super_admin!
      return if current_user.super_admin?

      redirect_to admin_root_path,
                  alert: "Only the Chairman or Secretary can open this page."
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
                  alert: "Your account doesn't have finance access yet."
    end

    def current_finance_unit
      @current_finance_unit ||= begin
        # "all" is the consolidated report selector, not a unit of its own.
        requested_id = params[:finance_unit_id].presence
        requested_id = nil if requested_id == "all"
        requested_id ? available_finance_units.find(requested_id) : preferred_accessible_finance_unit
      end
    end

    # before_action for pages that work on one finance unit.
    def set_finance_unit
      @finance_unit = current_finance_unit
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
                  alert: "You don't have permission to manage this finance unit."
    end
  end
end
