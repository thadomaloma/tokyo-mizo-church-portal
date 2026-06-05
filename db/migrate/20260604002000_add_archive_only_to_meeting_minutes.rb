class AddArchiveOnlyToMeetingMinutes < ActiveRecord::Migration[8.1]
  def change
    add_column :meeting_minutes, :archive_only, :boolean, null: false, default: false
  end
end
