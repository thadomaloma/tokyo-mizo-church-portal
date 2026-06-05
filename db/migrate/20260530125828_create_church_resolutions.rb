class CreateChurchResolutions < ActiveRecord::Migration[8.1]
  def change
    create_table :church_resolutions do |t|
      t.string :title
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 1, null: false
      t.date :due_date
      t.datetime :completed_at

      t.references :meeting_minute, null: true, foreign_key: true
      t.references :assigned_to, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
