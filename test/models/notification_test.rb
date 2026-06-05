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
end
