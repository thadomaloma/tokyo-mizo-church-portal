# Leftovers from the first version of the app: units counted vouchers
# themselves (now finance_voucher_sequences, per year) and transactions had a
# payer name that no screen ever filled in.
class RemoveUnusedFinanceColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :finance_units, :voucher_sequence, :integer, default: 0, null: false
    remove_column :finance_transactions, :payer_name, :string
  end
end
