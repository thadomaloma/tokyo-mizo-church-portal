require "test_helper"

class SignInProtectionTest < ActionDispatch::IntegrationTest
  test "sign-in attempts are capped per IP address" do
    10.times { post user_session_path, params: { user: { email: users(:one).email, password: "wrong" } } }

    post user_session_path, params: { user: { email: users(:one).email, password: "password" } }

    assert_redirected_to new_user_session_path
    assert_equal "Too many sign-in attempts. Please wait a few minutes and try again.", flash[:alert]
    assert_nil cookies["remember_user_token"]
  end

  test "password reset requests are capped per IP address" do
    5.times { post user_password_path, params: { user: { email: users(:one).email } } }

    post user_password_path, params: { user: { email: users(:one).email } }

    assert_redirected_to new_user_password_path
    assert_equal "Too many reset requests. Please wait a few minutes and try again.", flash[:alert]
  end

  test "ten wrong passwords lock the account for an hour" do
    user = users(:three)
    10.times { post user_session_path, params: { user: { email: user.email, password: "wrong" } } }
    assert user.reload.access_locked?

    ActionController::Base.cache_store.clear # past the per-IP cap
    post user_session_path, params: { user: { email: user.email, password: "password" } }
    assert_match "Your account is locked", flash[:alert]

    travel 61.minutes do
      post user_session_path, params: { user: { email: user.email, password: "password" } }
      assert_redirected_to root_path
    end
  end

  test "saving a locked user in Settings unlocks them" do
    locked = users(:three)
    locked.lock_access!(send_instructions: false)
    sign_in_as users(:one)

    get admin_settings_path
    assert_select "[data-settings-users] .chip", text: "Locked"

    patch admin_user_path(locked), params: { user: { name: locked.name } }

    assert_redirected_to admin_settings_path
    assert_not locked.reload.access_locked?
  end

  test "pages send a content security policy and inline scripts carry its nonce" do
    get new_user_session_path

    policy = response.headers["Content-Security-Policy"]
    assert_match "script-src 'self' 'nonce-", policy
    assert_match "object-src 'none'", policy
    assert_match "frame-ancestors 'none'", policy

    nonce = policy[/'nonce-([^']+)'/, 1]
    scripts = Nokogiri::HTML(response.body).css("script")
    assert scripts.any?
    assert(scripts.all? { |script| script["nonce"] == nonce }, "every script tag carries the nonce")
    assert_no_match(/\son(click|change|submit|load)=/, response.body)
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
