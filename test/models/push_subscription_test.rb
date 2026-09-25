require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  test "requires endpoint, p256dh, and auth_key" do
    subscription = PushSubscription.new(user: users(:one))

    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "can't be blank"
    assert_includes subscription.errors[:p256dh], "can't be blank"
    assert_includes subscription.errors[:auth_key], "can't be blank"
  end

  test "endpoint must be unique across all users" do
    PushSubscription.create!(
      user: users(:one),
      endpoint: "https://push.example.com/unique-endpoint",
      p256dh: "p256dh-key",
      auth_key: "auth-key"
    )

    duplicate = PushSubscription.new(
      user: users(:two),
      endpoint: "https://push.example.com/unique-endpoint",
      p256dh: "other-key",
      auth_key: "other-auth"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:endpoint], "has already been taken"
  end

  test "requires a user" do
    subscription = PushSubscription.new(
      endpoint: "https://push.example.com/no-user",
      p256dh: "key",
      auth_key: "auth"
    )

    assert_not subscription.valid?
    assert_includes subscription.errors[:user], "must exist"
  end

  test "a user may have multiple subscriptions for different devices" do
    user = users(:one)

    PushSubscription.create!(user: user, endpoint: "https://push.example.com/phone", p256dh: "a", auth_key: "b")
    PushSubscription.create!(user: user, endpoint: "https://push.example.com/laptop", p256dh: "c", auth_key: "d")

    assert_equal 2, user.push_subscriptions.count
  end
end
