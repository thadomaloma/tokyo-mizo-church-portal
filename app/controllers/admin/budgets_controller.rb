module Admin
  class BudgetsController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_unit
    before_action :set_year
    before_action :require_budget_manager!, only: %i[edit update]

    def index
      redirect_to admin_budget_path(@year, finance_unit_id: params[:finance_unit_id].presence)
    end

    def show
      @progress = BudgetProgress.new(@finance_unit, @year)
    end

    def edit
      @budget = FinanceBudget.includes(:lines).find_or_initialize_by(finance_unit: @finance_unit, year: @year)
      @amounts = @budget.lines.to_h { |line| [ line.finance_category_id, line.amount ] }
      load_form
    end

    def update
      @budget = FinanceBudget.find_or_initialize_by(finance_unit: @finance_unit, year: @year)
      @amounts = YenAmounts.parse(params.fetch(:amounts, {}).permit(*expense_categories.map { |category| category.id.to_s }))

      if @budget.update_amounts(@amounts, expense_categories)
        redirect_to admin_budget_path(@year, finance_unit_id: @finance_unit.id), notice: "#{@year} budget saved."
      else
        load_form
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_year
      year = params[:year].to_i
      @year = year.between?(2000, 2200) ? year : Date.current.year
    end

    def expense_categories
      @expense_categories ||= @finance_unit.finance_categories.system_defined.expense.order(:position, :name)
    end

    def load_form
      @categories = expense_categories
      @last_year_spent = @finance_unit.finance_transactions.expense
                                             .where(transaction_date: Date.new(@year - 1).all_year)
                                             .group(:finance_category_id).sum(:amount)
    end

    def require_budget_manager!
      return if can_manage_current_finance_unit?

      redirect_to admin_budget_path(@year, finance_unit_id: @finance_unit&.id),
                  alert: "You need permission to manage this finance unit to edit its budget."
    end
  end
end
