module Admin
  class FinanceUnitsController < BaseController
    before_action :require_super_admin!

    def index
      @finance_units = FinanceUnit
                       .includes(finance_unit_memberships: :user)
                       .ordered
      @users = User.active.where.not(role: %i[president secretary]).order(:name)
    end
  end
end
