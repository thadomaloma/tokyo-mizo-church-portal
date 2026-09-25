module Admin
  class FinancePeriodsController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_unit
    before_action :set_period_bounds
    before_action :set_finance_period
    before_action :require_finance_unit_manager!, only: %i[close reopen]

    def show
      transactions = @finance_unit.finance_transactions
                                   .includes(:finance_category)
                                   .where(transaction_date: @period_start..@period_end)
                                   .latest

      @transactions = transactions
      @income = transactions.income.sum(:amount)
      @expense = transactions.expense.sum(:amount)
      @net_change = @income - @expense

      prior_transactions = @finance_unit.finance_transactions.where("transaction_date < ?", @period_start)
      @opening_balance = prior_transactions.income.sum(:amount) - prior_transactions.expense.sum(:amount)
      @closing_balance = @opening_balance + @net_change

      @income_by_category = transactions.income.joins(:finance_category)
                                         .reorder(nil)
                                         .group("finance_categories.name")
                                         .sum(:amount)
      @expense_by_category = transactions.expense.joins(:finance_category)
                                          .reorder(nil)
                                          .group("finance_categories.name")
                                          .sum(:amount)

      @closing_issues = closing_issues(transactions)
    end

    def close
      if closing_issues(period_transactions).any?
        redirect_to admin_finance_period_path(@year, @month, finance_unit_id: @finance_unit.id),
                    alert: "He thla hi close theih a la ni lo — a hnuaia issue te siam tha hmasa rawh."
        return
      end

      @finance_period.close!(current_user)
      redirect_to admin_finance_period_path(@year, @month, finance_unit_id: @finance_unit.id),
                  notice: "#{@period_label} close fel a ni."
    end

    def reopen
      @finance_period.reopen!(current_user)
      redirect_to admin_finance_period_path(@year, @month, finance_unit_id: @finance_unit.id),
                  notice: "#{@period_label} edit theih turin reopen a ni."
    end

    private

    def set_finance_unit
      requested_id = params[:finance_unit_id].presence
      @finance_unit = requested_id ? available_finance_units.find(requested_id) : current_finance_unit
      @current_finance_unit = @finance_unit
    end

    def set_period_bounds
      @year = params[:year].to_i
      @month = params[:month].to_i

      unless @month.between?(1, 12)
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), alert: "Thla thlan a dik lo."
        return
      end

      @period_start = Date.new(@year, @month, 1)
      @period_end = @period_start.end_of_month
      @period_label = @period_start.strftime("%B %Y")
    end

    def set_finance_period
      @finance_period = FinancePeriod.find_or_open(@finance_unit, @year, @month)
    end

    def period_transactions
      @finance_unit.finance_transactions.where(transaction_date: @period_start..@period_end)
    end

    # Real, checkable data-integrity issues only — every one of these is
    # already prevented by existing model validations in normal use, so
    # this should almost always come back empty; it exists as a safety net,
    # not to manufacture the appearance of enterprise rigor.
    def closing_issues(transactions)
      issues = []

      missing_vouchers = transactions.where(transaction_type: "expense", voucher_number: nil).count
      if missing_vouchers.positive?
        issues << "Expense transaction #{missing_vouchers} ah voucher number a awm lo."
      end

      issues
    end
  end
end
