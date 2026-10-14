module Admin
  class FinanceTransactionsController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_transaction, only: %i[edit update destroy receipt]
    before_action :set_finance_unit, only: %i[index new create]
    before_action :require_finance_unit_manager!, except: %i[index receipt]

    def index
      @query = params[:q].presence
      @type_filter = params[:transaction_type].presence_in(FinanceTransaction::TYPES)
      @category_filter = params[:category_id].presence
      @payment_location_filter = params[:payment_location].presence_in(FinanceTransaction::LOCATIONS)
      @filter_categories = @finance_unit.finance_categories.system_defined.order(:category_type, :position, :name)

      @pagy, @transactions = pagy(finance_ledger_transactions, limit: 15)
      @transactions_count = @pagy.count
      @closed_periods = @finance_unit.finance_periods.closed.pluck(:year, :month).to_set
    end

    def receipt
      return if @finance_transaction.expense?

      redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id),
                  alert: "Receipt chu sum chhuak record atan chauh a awm."
    end

    def new
      transaction_type = params[:transaction_type].presence_in(FinanceTransaction::TYPES) || "expense"
      @finance_transaction = FinanceTransaction.new(
        transaction_type: transaction_type,
        transaction_date: Date.current,
        finance_unit: @finance_unit,
        payment_location: "cash",
        transfer_to_location: ("bank" if transaction_type == "transfer")
      )

      load_categories
    end

    def create
      @finance_transaction = FinanceTransaction.new(finance_transaction_attributes)
      @finance_transaction.recorded_by = current_user
      @finance_transaction.finance_unit = @finance_unit

      if closed_period_for(@finance_transaction.transaction_date)
        load_categories
        flash.now[:alert] = closed_period_message(@finance_transaction.transaction_date)
        render :new, status: :unprocessable_entity
      elsif @finance_transaction.save
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), notice: "Finance entry save fel a ni."
      else
        load_categories
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_categories
    end

    def update
      new_attrs = finance_transaction_attributes
      submitted_date = FinanceTransaction.type_for_attribute("transaction_date").cast(new_attrs[:transaction_date])
      new_date = submitted_date || @finance_transaction.transaction_date
      blocking_date = closed_period_for(@finance_transaction.transaction_date) ? @finance_transaction.transaction_date : nil
      blocking_date ||= new_date if closed_period_for(new_date)

      if blocking_date
        load_categories
        flash.now[:alert] = closed_period_message(blocking_date)
        render :edit, status: :unprocessable_entity
      elsif @finance_transaction.update(new_attrs)
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), notice: "Finance entry siamthat fel a ni."
      else
        load_categories
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if closed_period_for(@finance_transaction.transaction_date)
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id),
                    alert: closed_period_message(@finance_transaction.transaction_date)
        return
      end

      @finance_transaction.destroy
      redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), notice: "Finance entry delete fel a ni."
    end

    private

    def set_finance_transaction
      @finance_transaction = FinanceTransaction
                               .where(finance_unit: available_finance_units)
                               .find(params[:id])
      @finance_unit = @finance_transaction.finance_unit
      @current_finance_unit = @finance_unit
    end

    def set_finance_unit
      requested_id = params[:finance_unit_id].presence ||
                     params.dig(:finance_transaction, :finance_unit_id).presence
      @finance_unit = requested_id ? available_finance_units.find(requested_id) : current_finance_unit
      @current_finance_unit = @finance_unit
    end

    def load_categories
      @finance_categories =
        @finance_unit.finance_categories.system_defined
          .for_transaction_type(selected_transaction_type)
          .order(:position, :name)
    end

    def finance_transaction_params
      params.require(:finance_transaction).permit(
        :transaction_type,
        :finance_category_id,
        :amount,
        :transaction_date,
        :payment_location,
        :transfer_to_location,
        :description
      )
    end

    def finance_transaction_attributes
      attrs = finance_transaction_params.to_h.symbolize_keys
      if attrs.key?(:finance_category_id)
        category_id = attrs.delete(:finance_category_id)
        attrs[:finance_category] = @finance_unit.finance_categories.system_defined.find_by(id: category_id)
      end

      attrs
    end

    def closed_period_for(date)
      return nil unless date

      FinancePeriod.find_by(finance_unit: @finance_unit, year: date.year, month: date.month, status: :closed)
    end

    def closed_period_message(date)
      "#{date.strftime("%B %Y")} close a ni. Thlakna siam hmain Monthly Review atangin reopen rawh."
    end

    def finance_ledger_transactions
      transactions = finance_transactions
                       .includes(:finance_category)
                       .latest

      transactions = transactions.where(transaction_type: @type_filter) if @type_filter
      transactions = transactions.where(finance_category_id: @category_filter) if @category_filter
      if @payment_location_filter
        transactions = transactions.where(payment_location: @payment_location_filter)
                                   .or(transactions.where(transfer_to_location: @payment_location_filter))
      end
      transactions = search_transactions(transactions, @query) if @query

      transactions
    end

    def search_transactions(transactions, query)
      pattern = "%#{query}%"

      transactions.left_joins(:finance_category).where(
        "finance_categories.name LIKE :q OR finance_transactions.description LIKE :q",
        q: pattern
      )
    end

    def selected_transaction_type
      @finance_transaction.transaction_type.presence ||
        params.dig(:finance_transaction, :transaction_type).presence ||
        params[:transaction_type].presence
    end


    def finance_transactions
      @finance_unit.finance_transactions
    end
  end
end
