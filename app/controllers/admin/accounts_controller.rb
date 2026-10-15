module Admin
  class AccountsController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_unit

    def index
      @finance_summary = FinanceSummary.new(@finance_unit)
      @accounts = FinanceTransaction::LOCATIONS.map { |location| account_overview(location) }
      @balance_history = @finance_summary.balance_history(12)
    end

    private

    def account_overview(location)
      transactions = @finance_unit.finance_transactions
      month_in, month_out = @finance_summary.account_month_flow(location)

      {
        location: location,
        name: FinanceTransaction::LOCATION_LABELS.fetch(location),
        balance: @finance_summary.account_balance(location),
        month_in: month_in,
        month_out: month_out,
        recent: transactions.where(payment_location: location).or(transactions.where(transfer_to_location: location))
                            .includes(:finance_category).latest.limit(5)
      }
    end
  end
end
