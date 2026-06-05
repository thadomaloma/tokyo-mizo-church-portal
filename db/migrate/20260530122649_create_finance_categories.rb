class CreateFinanceCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_categories do |t|
      t.string :name
      t.string :category_type

      t.timestamps
    end
  end
end
