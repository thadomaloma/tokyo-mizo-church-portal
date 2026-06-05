module Admin
  class FinanceTransactionsController < BaseController
    before_action :require_finance_admin!, except: %i[index show]
    before_action :set_finance_transaction, only: %i[show edit update destroy]

    def index
      @transactions = FinanceTransaction
                        .includes(:finance_category)
                        .latest

      @monthly_income = FinanceTransaction.income.this_month.sum(:amount)
      @monthly_expense = FinanceTransaction.expense.this_month.sum(:amount)

      @cash_balance =
        FinanceTransaction.income.cash_records.sum(:amount) -
        FinanceTransaction.expense.cash_records.sum(:amount)

      @bank_balance =
        FinanceTransaction.income.bank_records.sum(:amount) -
        FinanceTransaction.expense.bank_records.sum(:amount)
    end

    def show; end

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
      @finance_categories = FinanceCategory.order(:category_type, :name)
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
