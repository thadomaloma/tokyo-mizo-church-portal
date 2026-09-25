class CreateFinancePeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_periods do |t|
      t.references :finance_unit, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.integer :status, null: false, default: 0
      t.datetime :closed_at
      t.references :closed_by, foreign_key: { to_table: :users }
      t.datetime :reopened_at
      t.references :reopened_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :finance_periods, %i[finance_unit_id year month], unique: true
  end
end
