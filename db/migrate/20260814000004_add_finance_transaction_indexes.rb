class AddFinanceTransactionIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :finance_transactions, :transaction_date, algorithm: :concurrently
    add_index :finance_transactions,
              %i[finance_unit_id transaction_type transaction_date],
              algorithm: :concurrently,
              name: "index_finance_transactions_on_unit_type_date"
  end
end
