# Lets a unit show its bank's name (e.g. "Yucho Bank") instead of "Bank".
class AddBankAccountNameToFinanceUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :finance_units, :bank_account_name, :string
  end
end
