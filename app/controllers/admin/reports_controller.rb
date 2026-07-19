module Admin
  class ReportsController < BaseController
    def index
      @total_income = FinanceTransaction.income.this_year.sum(:amount)
      @total_expense = FinanceTransaction.expense.this_year.sum(:amount)
      @balance = @total_income - @total_expense

      @monthly_income = FinanceTransaction.income.this_month.sum(:amount)
      @monthly_expense = FinanceTransaction.expense.this_month.sum(:amount)

      @total_members = User.count
      @active_members = User.where(active: true).count

      @pending_resolutions = ChurchResolution.where(status: 0).count
      @completed_resolutions = ChurchResolution.where(status: 2).count
      @overdue_resolutions = ChurchResolution.overdue.count
    end

    def finance
      @period_year = selected_finance_year
      @start_month = selected_finance_month(:start_month, 1)
      @end_month = selected_finance_month(:end_month, Date.current.month)
      @start_month, @end_month = [ @start_month, @end_month ].minmax
      @period_label = finance_period_label(@period_year, @start_month, @end_month)
      @month_options = finance_month_options
      @year_options = finance_year_options

      transactions = finance_transactions_for_period(@period_year, @start_month, @end_month)
      @report_transactions = transactions.to_a
      @income = transactions.income.sum(:amount)
      @expense = transactions.expense.sum(:amount)
      @balance = @income - @expense
      @finance_report_data = FinanceReportData.new(
        transactions: @report_transactions,
        income: @income,
        expense: @expense,
        balance: @balance,
        period_year: @period_year,
        start_month: @start_month,
        end_month: @end_month
      )

      respond_to do |format|
        format.html do
          @pagy, @ledger_transactions = pagy(transactions, limit: 12)
        end

        format.pdf do
          pdf = FinanceReportPdf.new(
            transactions: @report_transactions,
            income: @income,
            expense: @expense,
            balance: @balance,
            period_label: @period_label,
            period_year: @period_year,
            start_month: @start_month,
            end_month: @end_month
          )

          send_data pdf.render,
                    filename: "tokyo_mizo_church_finance_report_#{finance_period_filename}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end

        format.xlsx do
          @transactions = @report_transactions

          response.headers[
            "Content-Disposition"
          ] = "attachment; filename=tokyo_mizo_church_finance_report_#{finance_period_filename}.xlsx"
        end
      end
    end

    def resolutions
      @church_resolutions = ChurchResolution.includes(:assigned_to).latest
      @pending_count = ChurchResolution.where(status: 0).count
      @completed_count = ChurchResolution.where(status: 2).count
      @overdue_count = ChurchResolution.overdue.count
    end

    def members
      @users = User.order(:role, :name)
      @total_members = User.count
      @active_members = User.where(active: true).count
      @inactive_members = User.where(active: false).count
    end

    private

    def selected_finance_year
      year = params[:year].to_i

      return year if year.positive?

      Date.current.year
    end

    def selected_finance_month(param_name, fallback)
      month = params[param_name].to_i

      return month if month.between?(1, 12)

      fallback
    end

    def finance_month_options
      Date::MONTHNAMES.each_with_index.filter_map do |month_name, index|
        [ month_name, index ] if index.positive?
      end
    end

    def finance_year_options
      transaction_years = FinanceTransaction
                            .where.not(transaction_date: nil)
                            .distinct
                            .pluck(:transaction_date)
                            .map(&:year)

      (transaction_years + [ Date.current.year ]).uniq.sort.reverse
    end

    def finance_period_label(year, start_month, end_month)
      start_name = Date::MONTHNAMES[start_month]
      end_name = Date::MONTHNAMES[end_month]

      return "#{start_name} #{year}" if start_month == end_month

      "#{start_name} - #{end_name} #{year}"
    end

    def finance_period_filename
      "#{@period_year}_#{@start_month.to_s.rjust(2, "0")}_to_#{@end_month.to_s.rjust(2, "0")}_#{Date.current}"
    end

    def finance_transactions_for_period(year, start_month, end_month)
      period_start = Date.new(year, start_month, 1)
      period_end = Date.new(year, end_month, -1)

      transactions = FinanceTransaction
                       .includes(:finance_category, :recorded_by)
                       .order(transaction_date: :desc, created_at: :desc)

      transactions.where(transaction_date: period_start..period_end)
    end
  end
end
