class CreateFinanceTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_transactions do |t|
      t.string :transaction_type
      t.integer :amount
      t.date :transaction_date
      t.string :payer_name
      t.text :description
      t.references :finance_category, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
