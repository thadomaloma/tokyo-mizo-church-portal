module Admin
  # Sunday collection entry: one form for every income category counted after
  # a service (tithe, offering, thanksgiving, ...), saved as one income record
  # per category. Mirrors how counters work from a single count sheet.
  class OfferingsController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_unit
    before_action :require_finance_unit_manager!

    def new
      @date = Date.current - Date.current.wday
      @payment_location = "cash"
      @amounts = {}
      load_categories
    end

    def create
      load_categories
      @date = FinanceTransaction.type_for_attribute("transaction_date").cast(params[:transaction_date])
      @payment_location = params[:payment_location].presence_in(FinanceTransaction::LOCATIONS) || "cash"
      @counted_by = params[:counted_by].to_s.squish.first(120)
      @note = params[:note].to_s.squish.first(200)
      @amounts = submitted_amounts

      error = validation_error
      return render_error(error) if error

      FinanceTransaction.transaction do
        @categories.each do |category|
          amount = @amounts[category.id]
          next unless amount&.positive?

          @finance_unit.finance_transactions.create!(
            transaction_type: "income",
            finance_category: category,
            amount: amount,
            transaction_date: @date,
            payment_location: @payment_location,
            description: description,
            recorded_by: current_user
          )
        end
      end

      redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id),
                  notice: "#{@date.strftime("%-d %B")} thawhlawm ¥#{@amounts.values.sum.to_fs(:delimited)} save a ni."
    end

    private

    def set_finance_unit
      @finance_unit = current_finance_unit
    end

    def load_categories
      @categories = @finance_unit.finance_categories.system_defined.income
                                 .where.not(code: "opening_balance")
                                 .order(:position, :name)
    end

    def submitted_amounts
      permitted = params.fetch(:amounts, {}).permit(*@categories.map { |category| category.id.to_s })

      permitted.to_h.each_with_object({}) do |(category_id, value), amounts|
        cleaned = value.to_s.delete(",").strip
        next if cleaned.blank?

        amounts[category_id.to_i] = cleaned.match?(/\A\d+\z/) ? cleaned.to_i : -1
      end
    end

    def validation_error
      return "Ni (date) thlang rawh." if @date.blank?
      return "Amount chu number (yen) chauh ziak rawh." if @amounts.values.any?(&:negative?)
      return "Category pakhat tal amount ziak rawh." unless @amounts.values.any?(&:positive?)

      if FinancePeriod.exists?(finance_unit: @finance_unit, year: @date.year, month: @date.month, status: :closed)
        "#{@date.strftime("%B %Y")} chu close a ni. Monthly report atangin reopen hmasa rawh."
      end
    end

    def render_error(message)
      flash.now[:alert] = message
      render :new, status: :unprocessable_entity
    end

    def description
      parts = [ "Pathianni thawhlawm" ]
      parts << "Chhiartu: #{@counted_by}" if @counted_by.present?
      parts << @note if @note.present?
      parts.join(" · ")
    end
  end
end
