class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.string :title
      t.text :message
      t.string :notification_type
      t.string :link
      t.references :actor, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
