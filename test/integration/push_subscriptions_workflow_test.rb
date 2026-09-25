require "test_helper"

class PushSubscriptionsWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "subscription endpoints require authentication" do
    post admin_push_subscription_path, params: {
      subscription: { endpoint: "https://push.example.com/anon", p256dh: "key", auth_key: "auth" }
    }, as: :json

    assert_response :unauthorized
    assert_equal 0, PushSubscription.count
  end

  test "creating a subscription always owns it as the current user" do
    sign_in(@user)

    assert_difference -> { PushSubscription.count }, 1 do
      post admin_push_subscription_path, params: {
        subscription: { endpoint: "https://push.example.com/device-1", p256dh: "key", auth_key: "auth" }
      }, as: :json
    end

    assert_response :created
    subscription = PushSubscription.find_by(endpoint: "https://push.example.com/device-1")
    assert_equal @user, subscription.user
  end

  test "posting the same endpoint twice updates the existing row instead of duplicating" do
    sign_in(@user)

    post admin_push_subscription_path, params: {
      subscription: { endpoint: "https://push.example.com/device-2", p256dh: "old-key", auth_key: "old-auth" }
    }, as: :json

    assert_no_difference -> { PushSubscription.count } do
      post admin_push_subscription_path, params: {
        subscription: { endpoint: "https://push.example.com/device-2", p256dh: "new-key", auth_key: "new-auth" }
      }, as: :json
    end

    subscription = PushSubscription.find_by(endpoint: "https://push.example.com/device-2")
    assert_equal "new-key", subscription.p256dh
  end

  test "a re-subscribed endpoint transfers ownership to whoever is currently signed in (shared device)" do
    PushSubscription.create!(user: users(:two), endpoint: "https://push.example.com/shared-device", p256dh: "a", auth_key: "b")

    sign_in(@user)
    post admin_push_subscription_path, params: {
      subscription: { endpoint: "https://push.example.com/shared-device", p256dh: "a", auth_key: "b" }
    }, as: :json

    assert_equal @user, PushSubscription.find_by(endpoint: "https://push.example.com/shared-device").user
  end

  test "a user can only delete their own subscription" do
    other_users_subscription = PushSubscription.create!(
      user: users(:two), endpoint: "https://push.example.com/other-device", p256dh: "a", auth_key: "b"
    )

    sign_in(@user)
    assert_no_difference -> { PushSubscription.count } do
      delete admin_push_subscription_path, params: { endpoint: other_users_subscription.endpoint }, as: :json
    end

    assert PushSubscription.exists?(other_users_subscription.id)
  end

  test "unsubscribing removes the current user's own subscription" do
    PushSubscription.create!(user: @user, endpoint: "https://push.example.com/device-3", p256dh: "a", auth_key: "b")

    sign_in(@user)
    assert_difference -> { PushSubscription.count }, -1 do
      delete admin_push_subscription_path, params: { endpoint: "https://push.example.com/device-3" }, as: :json
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
