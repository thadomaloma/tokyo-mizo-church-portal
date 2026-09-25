class DropResolutions < ActiveRecord::Migration[8.1]
  def up
    drop_table :resolutions
  end

  def down
    create_table :resolutions do |t|
      t.string :title
      t.text :description
      t.integer :status
      t.integer :priority
      t.date :due_date
      t.datetime :completed_at
      t.references :meeting_minute, null: false, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
