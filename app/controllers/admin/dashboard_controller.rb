module Admin
  class DashboardController < BaseController
    def index
      @finance_unit = current_finance_unit
      load_finance_dashboard if @finance_unit

      @recent_transactions = if @finance_unit
        finance_transactions.includes(:finance_category).latest.limit(5)
      else
        FinanceTransaction.none
      end
    end

    private

    def load_finance_dashboard
      @finance_summary = FinanceSummary.new(@finance_unit)
      @current_balance = @finance_summary.current_balance
      @cash_balance = @finance_summary.cash_balance
      @bank_balance = @finance_summary.bank_balance
      load_monthly_giving_totals
      @monthly_finance_overview = monthly_finance_overview
      @monthly_income_total = @monthly_finance_overview.sum { |month| month[:income] }
      @monthly_expense_total = @monthly_finance_overview.sum { |month| month[:expense] }
    end

    def load_monthly_giving_totals
      transactions = finance_transactions
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

    def monthly_finance_overview
      months = (1..Date.current.month).map { |month| Date.new(Date.current.year, month, 1) }
      range = months.first..months.last.end_of_month
      rows = finance_transactions
               .where(transaction_date: range)
               .pluck(:transaction_type, :transaction_date, :amount)

      raw_points = months.map do |month|
        income = monthly_total(rows, month, "income")
        expense = monthly_total(rows, month, "expense")

        {
          label: month.strftime("%b"),
          income: income,
          expense: expense
        }
      end

      raw_points
    end

    def monthly_total(rows, month, transaction_type)
      rows.sum do |type, transaction_date, amount|
        next 0 unless type == transaction_type && transaction_date.to_date.beginning_of_month == month

        amount
      end
    end

    def finance_transactions
      @finance_unit.finance_transactions
    end
  end
end
