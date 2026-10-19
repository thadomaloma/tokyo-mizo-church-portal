module Admin
  # The monthly treasurer statement: opening balance, income and expenses by
  # category, closing balance with cash/bank, and the month's records.
  class FinancePeriodsController < BaseController
    include FinancePeriodScoped

    def show
      period = @finance_period
      @transactions = period.transactions.includes(:finance_category, :finance_unit).latest
      @income = @transactions.income.sum(:amount)
      @expense = @transactions.expense.sum(:amount)
      @net_change = @income - @expense

      summary = FinanceSummary.new(@finance_unit)
      @opening_balance = summary.balance_on(period.start_date - 1)
      @closing_balance = @opening_balance + @net_change
      @closing_accounts = FinanceTransaction::LOCATIONS.to_h { |location| [ location, summary.account_balance(location, on: period.end_date) ] }

      @income_by_category = category_totals(@transactions.income)
      @expense_by_category = category_totals(@transactions.expense)
      @budget_progress = BudgetProgress.new(@finance_unit, period.year)
      @closing_issues = period.closing_issues
    end

    private

    def category_totals(scope)
      scope.joins(:finance_category).reorder(nil)
           .group("finance_categories.name").sum(:amount)
           .sort_by { |_, amount| -amount }
    end
  end
end
