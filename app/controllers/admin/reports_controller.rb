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
  @transactions = FinanceTransaction
                    .includes(:finance_category, :recorded_by)
                    .this_year
                    .order(:transaction_date, :created_at)

  @income = @transactions.select(&:income?).sum(&:amount)
  @expense = @transactions.select(&:expense?).sum(&:amount)
  @balance = @income - @expense

  respond_to do |format|
    format.html

    format.pdf do
      pdf = FinanceReportPdf.new(
        transactions: @transactions,
        income: @income,
        expense: @expense,
        balance: @balance
      )

      send_data pdf.render,
                filename: "tokyo_mizo_church_finance_report_#{Date.current}.pdf",
                type: "application/pdf",
                disposition: "attachment"
    end

    format.xlsx do
      response.headers[
        "Content-Disposition"
      ] = "attachment; filename=tokyo_mizo_church_finance_report_#{Date.current}.xlsx"
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
  end
end
