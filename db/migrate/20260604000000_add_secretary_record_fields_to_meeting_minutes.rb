class AddSecretaryRecordFieldsToMeetingMinutes < ActiveRecord::Migration[8.1]
  def change
    add_column :meeting_minutes, :location, :string
    add_column :meeting_minutes, :start_time, :time
    add_column :meeting_minutes, :end_time, :time
    add_column :meeting_minutes, :chairperson, :string
    add_column :meeting_minutes, :secretary_name, :string
    add_column :meeting_minutes, :attendees, :text
    add_column :meeting_minutes, :absentees, :text
    add_column :meeting_minutes, :guests, :text
    add_column :meeting_minutes, :quorum_status, :string
    add_column :meeting_minutes, :call_to_order, :text
    add_column :meeting_minutes, :opening_prayer, :string
    add_column :meeting_minutes, :previous_minutes, :text
    add_column :meeting_minutes, :agenda_items, :text
    add_column :meeting_minutes, :old_business, :text
    add_column :meeting_minutes, :new_business, :text
    add_column :meeting_minutes, :motions, :text
    add_column :meeting_minutes, :action_items, :text
    add_column :meeting_minutes, :next_meeting_date, :date
    add_column :meeting_minutes, :adjournment, :text
    add_column :meeting_minutes, :approved_by, :string
    add_column :meeting_minutes, :approval_date, :date
  end
end
