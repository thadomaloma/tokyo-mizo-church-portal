module Admin
  class FinanceCategoriesController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_unit

    def index
      @finance_categories = @finance_unit.finance_categories.system_defined.order(:category_type, :position, :name)
    end

    private

    def set_finance_unit
      requested_id = params[:finance_unit_id].presence
      @finance_unit = requested_id ? available_finance_units.find(requested_id) : current_finance_unit
      @current_finance_unit = @finance_unit
    end
  end
end
