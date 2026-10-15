module Admin
  class BudgetsController < BaseController
    before_action :require_finance_access!
    before_action :set_year
    before_action :require_finance_unit_manager!, only: %i[edit update]

    def show
      @finance_unit = current_finance_unit
      @progress = BudgetProgress.new(@finance_unit, @year)
    end

    def edit
      @finance_unit = current_finance_unit
      load_form
    end

    def update
      @finance_unit = current_finance_unit
      budget = FinanceBudget.find_or_initialize_by(finance_unit: @finance_unit, year: @year)
      amounts = submitted_amounts

      if amounts.values.any?(&:negative?)
        load_form
        @amounts = amounts
        flash.now[:alert] = "Amounts must be whole numbers (yen)."
        return render :edit, status: :unprocessable_entity
      end

      FinanceBudget.transaction do
        budget.save!
        expense_categories.each do |category|
          line = budget.lines.find_or_initialize_by(finance_category: category)
          amount = amounts[category.id]

          if amount.to_i.positive?
            line.update!(amount: amount)
          elsif line.persisted?
            line.destroy!
          end
        end
      end

      redirect_to admin_budget_path(@year, finance_unit_id: @finance_unit.id), notice: "#{@year} budget saved."
    rescue ActiveRecord::RecordInvalid => error
      load_form
      @amounts = amounts
      flash.now[:alert] = error.record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
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
      @budget = FinanceBudget.includes(:lines).for(@finance_unit, @year)
      @amounts = @budget ? @budget.lines.to_h { |line| [ line.finance_category_id, line.amount ] } : {}
      @last_year_spent = @finance_unit.finance_transactions.expense
                                      .where(transaction_date: Date.new(@year - 1, 1, 1)..Date.new(@year - 1, 12, 31))
                                      .group(:finance_category_id).sum(:amount)
    end

    # { category_id => Integer } with blank fields dropped; commas allowed.
    def submitted_amounts
      permitted = params.fetch(:amounts, {}).permit(*expense_categories.map { |category| category.id.to_s })

      permitted.to_h.each_with_object({}) do |(category_id, value), amounts|
        cleaned = value.to_s.delete(",").strip
        next if cleaned.blank?

        amounts[category_id.to_i] = cleaned.match?(/\A\d+\z/) ? cleaned.to_i : -1
      end
    end

    def require_finance_unit_manager!
      return if can_manage_current_finance_unit?

      redirect_to admin_budget_path(@year, finance_unit_id: current_finance_unit&.id),
                  alert: "You need permission to manage this finance unit to edit its budget."
    end
  end
end
