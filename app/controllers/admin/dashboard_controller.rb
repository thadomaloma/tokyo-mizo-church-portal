module Admin
  class DashboardController < BaseController
    def index
      @finance_unit = current_finance_unit
      return unless @finance_unit

      @finance_summary = FinanceSummary.new(@finance_unit)
      @monthly_overview = @finance_summary.monthly_overview(6)
      @spending_pace = @finance_summary.spending_pace
      @budget_progress = BudgetProgress.new(@finance_unit, Date.current.year)
      @recent_transactions = @finance_unit.finance_transactions.includes(:finance_category).latest.limit(6)
      load_monthly_giving_totals
    end

    private

    def load_monthly_giving_totals
      transactions = @finance_unit.finance_transactions
                       .includes(:finance_category)
                       .this_month
                       .to_a

      month_row = FinanceReportData.new(
        transactions: transactions,
        income: 0,
        expense: 0,
        balance: 0,
        period_year: Date.current.year,
        start_month: Date.current.month,
        end_month: Date.current.month
      ).monthly_tithe_offering_rows.first

      @sawmapakhat_total = month_row[1]
      @weekly_offering_total = month_row[2]
    end
  end
end
