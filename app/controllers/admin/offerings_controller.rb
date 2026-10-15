module Admin
  # Sunday collection entry: one form for every income category counted after
  # a service, saved as one income record per category (see SundayOffering).
  class OfferingsController < BaseController
    before_action :require_finance_access!
    before_action :require_finance_unit_manager!

    def new
      @offering = SundayOffering.new(finance_unit: current_finance_unit)
    end

    def create
      @offering = SundayOffering.new(offering_params.merge(finance_unit: current_finance_unit, recorded_by: current_user))

      if @offering.save
        redirect_to admin_finance_transactions_path(finance_unit_id: current_finance_unit.id),
                    notice: "Offering of ¥#{@offering.total.to_fs(:delimited)} for #{@offering.transaction_date.strftime("%-d %B")} saved."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def offering_params
      params.expect(sunday_offering: [ :transaction_date, :payment_location, :counted_by, :note, amounts: {} ])
    end
  end
end
