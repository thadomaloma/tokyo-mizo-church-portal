class AddChurchFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :phone, :string
    add_column :users, :role, :integer
    add_column :users, :active, :boolean
  end
end
