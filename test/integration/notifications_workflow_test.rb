require "test_helper"

class NotificationsWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @visible_notification = notifications(:two)

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }
  end

  test "opening a visible notification marks it read and follows its internal link" do
    @visible_notification.update_column(:link, admin_finance_transactions_path)

    assert_difference -> { NotificationRead.where(notification: @visible_notification, user: @user).count }, 1 do
      get admin_notification_path(@visible_notification)
    end

    assert_redirected_to admin_finance_transactions_path
  end

  test "opening an already read notification does not create a duplicate read" do
    NotificationRead.create!(notification: @visible_notification, user: @user)
    @visible_notification.update_column(:link, admin_root_path)

    assert_no_difference -> { NotificationRead.where(notification: @visible_notification, user: @user).count } do
      get admin_notification_path(@visible_notification)
    end

    assert_redirected_to admin_root_path
  end

  test "an invalid stored link safely falls back to the dashboard" do
    @visible_notification.update_column(:link, "https://example.com")

    get admin_notification_path(@visible_notification)

    assert_redirected_to admin_root_path
  end

  test "a user cannot open their own notification" do
    get admin_notification_path(notifications(:one))

    assert_response :not_found
  end

  test "clear unread marks visible notifications but not the user's own notification" do
    assert_difference -> { NotificationRead.where(user: @user).count }, 1 do
      assert_no_difference -> { NotificationRead.where(notification: notifications(:one), user: @user).count } do
        patch mark_all_as_read_admin_notifications_path
      end
    end

    assert NotificationRead.exists?(notification: @visible_notification, user: @user)
    assert_redirected_to admin_root_path
  end

  test "the full notification history page shows more than the dropdown's cap and paginates" do
    25.times do |i|
      Notification.create!(
        actor: users(:two),
        title: "History item #{i}",
        message: "Message #{i}",
        notification_type: "member"
      )
    end

    get admin_notifications_path

    assert_response :success
    assert_includes response.body, "History item 24"
    assert_select "a", text: /Next/
  end

  test "the notification dropdown links to the full history page" do
    get admin_root_path

    assert_response :success
    assert_select "a[href=?]", admin_notifications_path, text: "View all notifications"
  end
end
