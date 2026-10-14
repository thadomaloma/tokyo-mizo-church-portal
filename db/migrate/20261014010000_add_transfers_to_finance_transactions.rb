class AddTransfersToFinanceTransactions < ActiveRecord::Migration[8.1]
  def change
    # A transfer moves money between a unit's own Cash and Bank accounts. It
    # has no category and never counts as income or expense.
    add_column :finance_transactions, :transfer_to_location, :string
    change_column_null :finance_transactions, :finance_category_id, true
  end
end
