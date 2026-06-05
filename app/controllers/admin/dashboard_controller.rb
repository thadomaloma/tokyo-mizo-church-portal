module Admin
  class DashboardController < BaseController
    def index
      @total_members = User.count

      @current_balance = FinanceTransaction.income.sum(:amount) - FinanceTransaction.expense.sum(:amount)

      @sawmapakhat_total = monthly_income_for("Sawmapakhat", "Sawm Pakhat", "Tithe")
      @mission_total = monthly_income_for("Mission", "Missionary", "Mission Fund")
      @weekly_offering_total = monthly_income_for("Thawhlawm", "Offering", "Weekly Offering")

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
  end
end
