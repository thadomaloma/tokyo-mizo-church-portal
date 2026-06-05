class AddPresentMemberIdsToMeetingMinutes < ActiveRecord::Migration[8.1]
  def change
    add_column :meeting_minutes, :present_member_ids, :jsonb, null: false, default: []
  end
end
