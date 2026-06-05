class AddUkChurchFieldsToMeetingMinutes < ActiveRecord::Migration[8.1]
  def change
    add_column :meeting_minutes, :correspondence, :text
    add_column :meeting_minutes, :reports, :text
    add_column :meeting_minutes, :safeguarding_notes, :text
    add_column :meeting_minutes, :any_other_business, :text
  end
end
