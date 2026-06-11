class AddVoucherNumberToFinanceTransactions < ActiveRecord::Migration[8.1]
  class MigrationFinanceTransaction < ActiveRecord::Base
    self.table_name = "finance_transactions"
  end

  def up
    add_column :finance_transactions, :voucher_number, :integer
    add_index :finance_transactions,
              :voucher_number,
              unique: true,
              where: "transaction_type = 'expense' AND voucher_number IS NOT NULL",
              name: "index_finance_transactions_on_expense_voucher_number"

    MigrationFinanceTransaction.reset_column_information

    MigrationFinanceTransaction
      .where(transaction_type: "expense")
      .order(:id)
      .each_with_index do |transaction, index|
        transaction.update_columns(voucher_number: index + 1)
      end
  end

  def down
    remove_index :finance_transactions,
                 name: "index_finance_transactions_on_expense_voucher_number"
    remove_column :finance_transactions, :voucher_number
  end
end
