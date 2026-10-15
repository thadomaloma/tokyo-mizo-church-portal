module Admin
  module FinanceTransactions
    # Printable payment voucher for an expense.
    class VouchersController < BaseController
      before_action :require_finance_access!

      def show
        @finance_transaction = FinanceTransaction.where(finance_unit: available_finance_units).find(params[:finance_transaction_id])
        @finance_unit = @finance_transaction.finance_unit
        return if @finance_transaction.expense?

        redirect_to admin_finance_transactions_path(finance_unit_id: @finance_unit.id),
                    alert: "Vouchers are only available for expenses."
      end
    end
  end
end
