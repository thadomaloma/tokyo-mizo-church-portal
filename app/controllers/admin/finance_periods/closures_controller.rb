module Admin
  module FinancePeriods
    # Closing a month (create) locks its transactions; reopening it
    # (destroy) unlocks them again.
    class ClosuresController < BaseController
      include FinancePeriodScoped

      before_action :require_finance_unit_manager!

      def create
        if @finance_period.closing_issues.any?
          redirect_to finance_period_path_for(@finance_period), alert: "This month can't be closed yet — fix the issues below first."
        else
          @finance_period.close!(current_user)
          redirect_to finance_period_path_for(@finance_period), notice: "#{@finance_period.label} closed."
        end
      end

      def destroy
        @finance_period.reopen!(current_user)
        redirect_to finance_period_path_for(@finance_period), notice: "#{@finance_period.label} reopened for changes."
      end
    end
  end
end
