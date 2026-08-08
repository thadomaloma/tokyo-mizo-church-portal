module Admin
  class FinanceTransactionsController < BaseController
    before_action :require_finance_admin!, except: :index
    before_action :set_finance_transaction, only: %i[edit update destroy receipt]

    def index
      @summary_month_options = finance_month_options
      @summary_year_options = finance_year_options

      @income_summary_year = selected_summary_year(:income_summary_year)
      @income_summary_month = selected_summary_month(:income_summary_month)
      @income_summary_month_label = finance_month_label(@income_summary_year, @income_summary_month)
      income_summary_period = finance_month_period(@income_summary_year, @income_summary_month)

      @expense_summary_year = selected_summary_year(:expense_summary_year)
      @expense_summary_month = selected_summary_month(:expense_summary_month)
      @expense_summary_month_label = finance_month_label(@expense_summary_year, @expense_summary_month)
      expense_summary_period = finance_month_period(@expense_summary_year, @expense_summary_month)

      @monthly_income = FinanceTransaction.income.where(transaction_date: income_summary_period).sum(:amount)
      @monthly_expense = FinanceTransaction.expense.where(transaction_date: expense_summary_period).sum(:amount)
      @ledger_filter = selected_ledger_filter
      @ledger_title = ledger_title
      @ledger_description = ledger_description

      @cash_balance =
        FinanceTransaction.income.cash_records.sum(:amount) -
        FinanceTransaction.expense.cash_records.sum(:amount)

      @bank_balance =
        FinanceTransaction.income.bank_records.sum(:amount) -
        FinanceTransaction.expense.bank_records.sum(:amount)

      transactions = finance_ledger_transactions

      @pagy, @transactions = pagy(transactions, limit: 10)
      @transactions_count = @pagy.count
    end

    def receipt
      return if @finance_transaction.expense?

      redirect_to admin_finance_transactions_path,
                  alert: "Receipt is only available for expense records."
    end

    def new
      @finance_transaction = FinanceTransaction.new(
        transaction_type: params[:transaction_type],
        transaction_date: Date.current
      )

      load_categories
    end

    def create
      @finance_transaction = FinanceTransaction.new(finance_transaction_params)
      @finance_transaction.recorded_by = current_user

      if @finance_transaction.save
        create_notification("New Finance Entry", "#{current_user.name} added #{@finance_transaction.transaction_type.humanize} record.")
        redirect_to admin_finance_transactions_path, notice: "Finance entry was saved."
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
        create_notification("Finance Entry Updated", "#{current_user.name} updated a finance record.")
        redirect_to admin_finance_transactions_path, notice: "Finance entry was updated."
      else
        load_categories
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @finance_transaction.destroy
      redirect_to admin_finance_transactions_path, notice: "Finance entry was deleted."
    end

    private

    def set_finance_transaction
      @finance_transaction = FinanceTransaction.find(params[:id])
    end

    def load_categories
      @finance_categories =
        FinanceCategory
          .for_transaction_type(selected_transaction_type)
          .order(:name)
    end

    def finance_transaction_params
      params.require(:finance_transaction).permit(
        :transaction_type,
        :finance_category_id,
        :amount,
        :transaction_date,
        :payment_location,
        :description
      )
    end

    def selected_summary_year(param_name)
      legacy_year = params[:summary_year].to_i
      year = params[param_name].presence&.to_i || legacy_year

      return year if year.positive?

      Date.current.year
    end

    def selected_summary_month(param_name)
      legacy_month = params[:summary_month].to_i
      month = params[param_name].presence&.to_i || legacy_month

      return month if month.between?(1, 12)

      Date.current.month
    end

    def finance_month_label(year, month)
      Date.new(year, month, 1).strftime("%B %Y")
    end

    def finance_month_period(year, month)
      Date.new(year, month, 1).all_month
    end

    def finance_month_options
      Date::MONTHNAMES.each_with_index.filter_map do |month_name, index|
        [ month_name, index ] if index.positive?
      end
    end

    def finance_year_options
      transaction_years = FinanceTransaction
                            .where.not(transaction_date: nil)
                            .distinct
                            .pluck(:transaction_date)
                            .map(&:year)

      (transaction_years + [ Date.current.year ]).uniq.sort.reverse
    end

    def selected_ledger_filter
      filter = params[:ledger_filter].to_s

      filter.in?(%w[income expense]) ? filter : nil
    end

    def finance_ledger_transactions
      transactions = FinanceTransaction
                       .includes(:finance_category)
                       .latest

      case @ledger_filter
      when "income"
        transactions.income.where(transaction_date: finance_month_period(@income_summary_year, @income_summary_month))
      when "expense"
        transactions.expense.where(transaction_date: finance_month_period(@expense_summary_year, @expense_summary_month))
      else
        transactions
      end
    end

    def ledger_title
      case @ledger_filter
      when "income"
        "Income Transactions"
      when "expense"
        "Expense Transactions"
      else
        "Recent Transactions"
      end
    end

    def ledger_description
      case @ledger_filter
      when "income"
        "Income records for #{@income_summary_month_label}."
      when "expense"
        "Expense records for #{@expense_summary_month_label}."
      else
        "Latest income and expense records."
      end
    end

    def selected_transaction_type
      @finance_transaction.transaction_type.presence ||
        params.dig(:finance_transaction, :transaction_type).presence ||
        params[:transaction_type].presence
    end

    def create_notification(title, message)
      NotificationCreator.call(
        actor: current_user,
        title: title,
        message: message,
        notification_type: "finance",
        link: admin_finance_transactions_path
      )
    end
  end
end
