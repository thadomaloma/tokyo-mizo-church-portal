class AddPaymentLocationToFinanceTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :finance_transactions, :payment_location, :string, null: false, default: "cash"
    add_index :finance_transactions, :payment_location
  end
end
