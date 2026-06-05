module Admin
  class DashboardController < BaseController
    def index
      @total_members = User.count

      @current_balance = FinanceTransaction.income.sum(:amount) - FinanceTransaction.expense.sum(:amount)

      @sawmapakhat_total = monthly_income_for("Sawmapakhat")
      @mission_total = monthly_income_for("Mission")
      @weekly_offering_total = monthly_income_for("Thawhlawm")

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

    def monthly_income_for(category_name)
      FinanceTransaction
        .income
        .this_month
        .for_category(category_name)
        .sum(:amount)
    end
  end
end
