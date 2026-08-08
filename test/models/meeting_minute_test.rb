require "test_helper"

class MeetingMinuteTest < ActiveSupport::TestCase
  test "rejects a non PDF archive upload" do
    minute = MeetingMinute.new(
      title: "Archive",
      meeting_type: "OB Meeting",
      meeting_date: Date.current,
      archive_only: true,
      uploaded_by: users(:one)
    )
    minute.pdf_file.attach(
      io: StringIO.new("not a pdf"),
      filename: "minute.txt",
      content_type: "text/plain"
    )

    assert_not minute.valid?
    assert_includes minute.errors[:pdf_file], "must be a PDF file"
  end

  test "creates linked resolutions from follow up action lines" do
    minute = nil

    assert_difference -> { ChurchResolution.count }, 2 do
      minute = MeetingMinute.create!(
        title: "June OB Minute",
        meeting_type: "OB Meeting",
        meeting_date: Date.current,
        next_meeting_date: Date.current + 1.month,
        action_items: "<ol><li>Repair sound system</li><li>Visit new member</li></ol>",
        uploaded_by: users(:one)
      )
    end

    sound_resolution = ChurchResolution.find_by!(
      meeting_minute: minute,
      title: "Repair sound system"
    )

    assert_equal "pending", sound_resolution.status
    assert_equal "normal", sound_resolution.priority
    assert_equal minute.next_meeting_date, sound_resolution.due_date
  end

  test "does not duplicate linked resolutions on update" do
    minute = MeetingMinute.create!(
      title: "June EC Minute",
      meeting_type: "EC Meeting",
      meeting_date: Date.current,
      action_items: "1. Prepare youth report",
      uploaded_by: users(:one)
    )

    assert_no_difference -> { ChurchResolution.where(meeting_minute: minute).count } do
      minute.update!(description: "Updated summary")
    end
  end
end
