module Admin
  class FinanceCategoriesController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_unit

    def index
      @finance_categories = @finance_unit.finance_categories.system_defined.order(:category_type, :position, :name)
    end
  end
end
