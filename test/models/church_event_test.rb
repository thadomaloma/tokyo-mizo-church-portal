require "test_helper"

class ChurchEventTest < ActiveSupport::TestCase
  test "rejects an end time before the start time" do
    event = ChurchEvent.new(
      title: "Sunday Service",
      start_date: Time.zone.parse("2026-08-09 13:00"),
      end_date: Time.zone.parse("2026-08-09 12:00"),
      created_by: users(:one)
    )

    assert_not event.valid?
    assert_includes event.errors[:end_date], "cannot be before the start date and time"
  end
end
