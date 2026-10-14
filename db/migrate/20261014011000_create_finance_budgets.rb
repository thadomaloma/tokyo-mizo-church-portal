class CreateFinanceBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_budgets do |t|
      t.references :finance_unit, null: false, foreign_key: true
      t.integer :year, null: false
      t.timestamps
    end
    add_index :finance_budgets, %i[finance_unit_id year], unique: true

    create_table :finance_budget_lines do |t|
      t.references :finance_budget, null: false, foreign_key: true
      t.references :finance_category, null: false, foreign_key: true
      t.integer :amount, null: false
      t.timestamps
    end
    add_index :finance_budget_lines, %i[finance_budget_id finance_category_id], unique: true, name: "index_finance_budget_lines_on_budget_and_category"
  end
end
