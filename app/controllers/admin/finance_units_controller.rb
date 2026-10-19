module Admin
  class FinanceUnitsController < BaseController
    before_action :require_super_admin!
    before_action :set_finance_unit, only: %i[edit update]

    def index
      @finance_units = FinanceUnit
                       .includes(finance_unit_memberships: :user)
                       .ordered
      @users = User.active.where.not(role: %i[chairman secretary]).order(:name)
    end

    def new
      @finance_unit = FinanceUnit.new(unit_type: "department", active: true)
    end

    def create
      @finance_unit = FinanceUnit.new(finance_unit_params)
      @finance_unit.position = (FinanceUnit.maximum(:position) || 0) + 10

      FinanceUnit.transaction do
        @finance_unit.save!
        FinanceCategory.install_system_catalog_for!(@finance_unit)
      end

      redirect_to admin_finance_units_path, notice: "#{@finance_unit.name} created. Now assign a treasurer and viewers."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      if @finance_unit.update(finance_unit_params.except(:unit_type))
        redirect_to admin_finance_units_path, notice: "#{@finance_unit.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_finance_unit
      @finance_unit = FinanceUnit.find(params[:id])
    end

    def finance_unit_params
      params.expect(finance_unit: %i[name unit_type active bank_account_name])
    end
  end
end
