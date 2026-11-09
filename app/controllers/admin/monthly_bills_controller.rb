module Admin
  # The regular monthly bills on one form, saved as one expense per bill
  # (see MonthlyBills).
  class MonthlyBillsController < BaseController
    before_action :require_finance_access!
    before_action :require_finance_unit_manager!

    def new
      @bills = MonthlyBills.new(finance_unit: current_finance_unit, month: chosen_month)
    end

    def create
      @bills = MonthlyBills.new(bills_params.merge(finance_unit: current_finance_unit, recorded_by: current_user))

      if @bills.save
        redirect_to admin_finance_transactions_path(finance_unit_id: current_finance_unit.id),
                    notice: "#{helpers.pluralize(@bills.chosen.size, "bill")} for #{@bills.month.strftime("%B %Y")} saved (¥#{@bills.total.to_fs(:delimited)})."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def chosen_month
      Date.strptime(params[:month].to_s, "%Y-%m")
    rescue Date::Error
      Date.current
    end

    def bills_params
      permitted = params.expect(monthly_bills: [ :transaction_date, entries: {} ])
      permitted.merge(month: chosen_month)
    end
  end
end
