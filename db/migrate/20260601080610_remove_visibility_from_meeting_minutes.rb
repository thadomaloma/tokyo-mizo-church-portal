class RemoveVisibilityFromMeetingMinutes < ActiveRecord::Migration[8.0]
  def change
    remove_column :meeting_minutes, :visibility, :string
  end
end
