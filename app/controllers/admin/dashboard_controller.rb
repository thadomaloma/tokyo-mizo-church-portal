module Admin
  class DashboardController < BaseController
    def index
      @current_balance = FinanceTransaction.income.sum(:amount) - FinanceTransaction.expense.sum(:amount)

      @sawmapakhat_total = monthly_income_for("Sawmapakhat", "Sawm Pakhat", "Tithe")
      @weekly_offering_total = monthly_income_for("Thawhlawm", "Offering", "Weekly Offering")
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

    def monthly_income_for(*category_keywords)
      FinanceTransaction
        .income
        .this_month
        .for_category_keywords(category_keywords)
        .sum(:amount)
    end

    def monthly_finance_overview
      months = (0..5).map { |index| index.months.ago.to_date.beginning_of_month }.reverse
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
