module Admin
  class AccountsController < BaseController
    before_action :require_finance_access!

    def index
      @finance_unit = current_finance_unit
      @finance_summary = FinanceSummary.new(@finance_unit)
      @accounts = FinanceTransaction::LOCATIONS.map { |location| account_overview(location) }
      @balance_history = @finance_summary.balance_history(12)
    end

    private

    def account_overview(location)
      transactions = @finance_unit.finance_transactions
      touching = transactions.where(payment_location: location).or(transactions.where(transfer_to_location: location))
      month = Date.current.all_month

      {
        location: location,
        name: FinanceTransaction::LOCATION_LABELS.fetch(location),
        balance: @finance_summary.account_balance(location),
        month_in: transactions.income.where(payment_location: location, transaction_date: month).sum(:amount) +
                  transactions.transfers.where(transfer_to_location: location, transaction_date: month).sum(:amount),
        month_out: transactions.expense.where(payment_location: location, transaction_date: month).sum(:amount) +
                   transactions.transfers.where(payment_location: location, transaction_date: month).sum(:amount),
        recent: touching.includes(:finance_category).latest.limit(5)
      }
    end
  end
end
