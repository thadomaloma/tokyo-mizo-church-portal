class CreateChurchEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :church_events do |t|
      t.string :title
      t.text :description
      t.datetime :start_date
      t.datetime :end_date
      t.string :location
      t.string :event_type
      t.string :visibility
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
