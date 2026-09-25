require "test_helper"

class PushDeliveryJobTest < ActiveJob::TestCase
  test "loads the notification and hands it to PushNotificationService" do
    notification = Notification.create!(actor: users(:one), title: "General", message: "Update", notification_type: "member")

    delivered = nil
    original = PushNotificationService.method(:deliver)
    PushNotificationService.define_singleton_method(:deliver) { |n| delivered = n }

    PushDeliveryJob.perform_now(notification.id)

    assert_equal notification, delivered
  ensure
    PushNotificationService.define_singleton_method(:deliver, original) if original
  end

  test "discards the job instead of raising when the notification no longer exists" do
    assert_nothing_raised do
      PushDeliveryJob.perform_now(-1)
    end
  end
end
