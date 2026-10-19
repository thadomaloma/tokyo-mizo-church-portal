module Admin
  class FinanceTransactionsController < BaseController
    before_action :require_finance_access!
    before_action :set_finance_transaction, only: %i[edit update destroy]
    before_action :set_finance_unit, only: %i[index new create]
    before_action :require_finance_unit_manager!, except: :index

    def index
      @query = params[:q].presence
      @type_filter = params[:transaction_type].presence_in(FinanceTransaction.transaction_types.keys)
      @category_filter = params[:category_id].presence
      @payment_location_filter = params[:payment_location].presence_in(FinanceTransaction::LOCATIONS)
      @filter_categories = @finance_unit.finance_categories.system_defined.order(:category_type, :position, :name)

      @pagy, @transactions = pagy(finance_ledger_transactions, limit: 15)
      @transactions_count = @pagy.count
      @closed_periods = @finance_unit.finance_periods.closed.pluck(:year, :month).to_set
    end


    def new
      transaction_type = params[:transaction_type].presence_in(FinanceTransaction.transaction_types.keys) || "expense"
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
      @finance_transaction = @finance_unit.finance_transactions.new(finance_transaction_params)
      @finance_transaction.recorded_by = current_user

      if @finance_transaction.save
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), notice: "Transaction saved."
      else
        load_categories
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_categories
    end

    def update
      if @finance_transaction.update(finance_transaction_params)
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), notice: "Transaction updated."
      else
        load_categories
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @finance_transaction.destroy
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id), notice: "Transaction deleted."
      else
        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id),
                    alert: @finance_transaction.errors.full_messages.to_sentence
      end
    end

    private

    def set_finance_transaction
      @finance_transaction = FinanceTransaction
                               .where(finance_unit: available_finance_units)
                               .find(params[:id])
      @finance_unit = @finance_transaction.finance_unit
      @current_finance_unit = @finance_unit
    end

    # The transaction form also sends the unit inside finance_transaction[...].
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

    # Only this unit's fixed (system) categories can be chosen from the form;
    # anything else becomes nil and fails the model's category validation.
    def finance_transaction_params
      params.expect(finance_transaction: %i[transaction_type finance_category_id amount transaction_date
                                            payment_location transfer_to_location description]).tap do |attributes|
        next unless attributes.key?(:finance_category_id)

        attributes[:finance_category_id] = @finance_unit.finance_categories.system_defined
                                                        .find_by(id: attributes[:finance_category_id])&.id
      end
    end

    def finance_ledger_transactions
      transactions = finance_transactions
                       .includes(:finance_category, :finance_unit)
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
