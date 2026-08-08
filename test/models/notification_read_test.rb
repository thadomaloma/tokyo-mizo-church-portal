require "test_helper"

class NotificationReadTest < ActiveSupport::TestCase
  test "a user can only have one read record per notification" do
    existing_read = notification_reads(:one)
    duplicate = NotificationRead.new(
      notification: existing_read.notification,
      user: existing_read.user
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:notification_id], "has already been taken"
  end

  test "read_at is set when a read record is created" do
    read = NotificationRead.create!(
      notification: notifications(:two),
      user: users(:one)
    )

    assert read.read_at.present?
  end
end
