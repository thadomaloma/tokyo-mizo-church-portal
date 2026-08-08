module Admin
  class DashboardController < BaseController
    def index
      @current_balance = FinanceTransaction.income.sum(:amount) - FinanceTransaction.expense.sum(:amount)

      load_monthly_giving_totals
      @monthly_finance_overview = monthly_finance_overview
      @monthly_income_total = @monthly_finance_overview.sum { |month| month[:income] }
      @monthly_expense_total = @monthly_finance_overview.sum { |month| month[:expense] }

      @pending_resolutions = ChurchResolution.where(status: 0).count
      @overdue_resolutions = ChurchResolution.overdue.count

      @recent_transactions = FinanceTransaction
                               .includes(:finance_category)
                               .latest
                               .limit(5)

      @upcoming_events = ChurchEvent
                           .where("start_date >= ?", Time.current)
                           .order(start_date: :asc)
                           .limit(5)

      @events_this_month = ChurchEvent
                             .where(start_date: Time.current.beginning_of_month..Time.current.end_of_month)
                             .count

      @today_events_count = ChurchEvent
                              .where(start_date: Time.current.beginning_of_day..Time.current.end_of_day)
                              .count

      @recent_minutes = MeetingMinute.latest.limit(5)
    end

    private

    def load_monthly_giving_totals
      transactions = FinanceTransaction
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
      rows = FinanceTransaction
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
  end
end
