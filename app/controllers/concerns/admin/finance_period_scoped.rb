module Admin
  # Loads the finance unit and the month (FinancePeriod) named by the
  # /finance_periods/:year/:month URL, for the statement and its closure.
  module FinancePeriodScoped
    extend ActiveSupport::Concern

    included do
      before_action :require_finance_access!
      before_action :set_finance_period
    end

    private

    def set_finance_period
      @finance_unit = current_finance_unit
      year, month = params.values_at(:year, :month).map(&:to_i)

      unless month.between?(1, 12)
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), alert: "That month is not valid."
        return
      end

      @finance_period = FinancePeriod.find_or_open(@finance_unit, year, month)
    end

    def finance_period_path_for(period)
      admin_finance_period_path(period.year, period.month, finance_unit_id: period.finance_unit_id)
    end
  end
end
