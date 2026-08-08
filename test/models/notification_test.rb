require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "visible_for excludes notifications created by the same user" do
    actor = users(:one)

    assert_not_includes Notification.visible_for(actor), notifications(:one)
    assert_includes Notification.visible_for(actor), notifications(:two)
  end

  test "unread_for excludes notifications created by the same user" do
    actor = users(:one)

    assert_not_includes Notification.unread_for(actor), notifications(:one)
    assert_includes Notification.unread_for(actor), notifications(:two)
  end

  test "unread_for clears after all visible notifications are read" do
    user = users(:one)

    Notification.visible_for(user).find_each do |notification|
      NotificationRead.find_or_create_by!(
        notification: notification,
        user: user
      )
    end

    assert_empty Notification.unread_for(user)
  end

  test "visible_for includes notifications whose actor was removed" do
    notification = notifications(:two)
    notification.update_column(:actor_id, nil)

    assert_includes Notification.visible_for(users(:one)), notification
  end

  test "link must be an internal path" do
    notification = Notification.new(
      actor: users(:one),
      title: "Test",
      message: "Test notification",
      notification_type: "test"
    )

    notification.link = "https://example.com"
    assert_not notification.valid?
    assert_includes notification.errors[:link], "must be an internal path"

    notification.link = "/admin/reports"
    assert notification.valid?
  end

  test "read_by is safe for a missing user" do
    assert_not notifications(:one).read_by?(nil)
  end
end
