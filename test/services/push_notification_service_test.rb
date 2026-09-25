require "test_helper"

class PushNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @vapid = Rails.application.config.x.vapid
    @original_public_key = @vapid.public_key
    @original_private_key = @vapid.private_key
    @vapid.public_key = "test-public-key"
    @vapid.private_key = "test-private-key"
  end

  teardown do
    @vapid.public_key = @original_public_key
    @vapid.private_key = @original_private_key
  end

  test "delivers to every eligible recipient's subscriptions and skips the actor" do
    actor = users(:one)
    recipient = users(:two)
    PushSubscription.create!(user: recipient, endpoint: "https://push.example.com/recipient", p256dh: "a", auth_key: "b")
    PushSubscription.create!(user: actor, endpoint: "https://push.example.com/actor", p256dh: "a", auth_key: "b")

    notification = Notification.create!(actor: actor, title: "General", message: "Update", notification_type: "member")

    delivered_endpoints = []
    stub_webpush_payload_send(->(**kwargs) { delivered_endpoints << kwargs[:endpoint] }) do
      PushNotificationService.deliver(notification)
    end

    assert_equal [ "https://push.example.com/recipient" ], delivered_endpoints
  end

  test "does nothing when VAPID is not configured" do
    @vapid.public_key = nil
    @vapid.private_key = nil

    recipient = users(:two)
    subscription = PushSubscription.create!(user: recipient, endpoint: "https://push.example.com/unconfigured", p256dh: "a", auth_key: "b")
    notification = Notification.create!(actor: users(:one), title: "General", message: "Update", notification_type: "member")

    stub_webpush_payload_send(->(**_kwargs) { raise "should not be called" }) do
      PushNotificationService.deliver(notification)
    end

    assert_nil subscription.reload.last_used_at
  end

  test "redacts finance notification title and body regardless of stored message" do
    actor = users(:two)
    recipient = users(:one)
    PushSubscription.create!(user: recipient, endpoint: "https://push.example.com/finance-recipient", p256dh: "a", auth_key: "b")

    notification = Notification.create!(
      actor: actor,
      title: "New Finance Entry",
      message: "Main Church Finance: balance is now ¥1,430,500.",
      notification_type: "finance"
    )

    sent_message = nil
    stub_webpush_payload_send(->(**kwargs) { sent_message = JSON.parse(kwargs[:message]) }) do
      PushNotificationService.deliver(notification)
    end

    assert_equal "Finance Update", sent_message["title"]
    assert_equal "TMC Portal-ah finance record siamthat a ni.", sent_message["body"]
    assert_not_includes sent_message["body"], "1,430,500"
  end

  test "destroys the subscription when the push service reports it as gone" do
    recipient = users(:two)
    subscription = PushSubscription.create!(user: recipient, endpoint: "https://push.example.com/expired", p256dh: "a", auth_key: "b")
    notification = Notification.create!(actor: users(:one), title: "General", message: "Update", notification_type: "member")

    fake_response = Struct.new(:code, :message, :body).new("410", "Gone", "")

    stub_webpush_payload_send(->(**_kwargs) { raise Webpush::ExpiredSubscription.new(fake_response, "push.example.com") }) do
      PushNotificationService.deliver(notification)
    end

    assert_not PushSubscription.exists?(subscription.id)
  end

  test "a transient provider error does not remove the subscription" do
    recipient = users(:two)
    subscription = PushSubscription.create!(user: recipient, endpoint: "https://push.example.com/flaky", p256dh: "a", auth_key: "b")
    notification = Notification.create!(actor: users(:one), title: "General", message: "Update", notification_type: "member")

    fake_response = Struct.new(:code, :message, :body).new("500", "Internal Server Error", "")

    stub_webpush_payload_send(->(**_kwargs) { raise Webpush::PushServiceError.new(fake_response, "push.example.com") }) do
      PushNotificationService.deliver(notification)
    end

    assert PushSubscription.exists?(subscription.id)
  end

  test "a raw network error (unreachable endpoint) does not crash delivery or remove the subscription" do
    recipient = users(:two)
    other_recipient = User.create!(name: "Second Device Owner", email: "second-device-owner@example.com", password: "secure-password", role: :executive_member)
    subscription = PushSubscription.create!(user: recipient, endpoint: "https://push.example.com/unreachable", p256dh: "a", auth_key: "b")
    other_subscription = PushSubscription.create!(user: other_recipient, endpoint: "https://push.example.com/reachable", p256dh: "a", auth_key: "b")
    notification = Notification.create!(actor: users(:one), title: "General", message: "Update", notification_type: "member")

    delivered_to = []
    stub_webpush_payload_send(->(**kwargs) {
      raise SocketError, "getaddrinfo: Name or service not known" if kwargs[:endpoint] == subscription.endpoint

      delivered_to << kwargs[:endpoint]
    }) do
      PushNotificationService.deliver(notification)
    end

    assert PushSubscription.exists?(subscription.id), "a network error must not delete the subscription"
    assert_equal [ other_subscription.endpoint ], delivered_to, "one bad subscription must not block delivery to the rest"
  end
end
