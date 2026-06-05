class CreateMeetingMinutes < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_minutes do |t|
      t.string :title
      t.string :meeting_type
      t.date :meeting_date
      t.text :description
      t.string :visibility
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
