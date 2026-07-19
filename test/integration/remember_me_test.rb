require "test_helper"

class RememberMeTest < ActionDispatch::IntegrationTest
  test "checked remember me creates a persistent remember cookie" do
    post user_session_path, params: {
      user: {
        email: users(:one).email,
        password: "password",
        remember_me: "1"
      }
    }

    assert_response :redirect
    assert cookies["remember_user_token"].present?
  end

  test "unchecked remember me does not create a remember cookie" do
    post user_session_path, params: {
      user: {
        email: users(:one).email,
        password: "password",
        remember_me: "0"
      }
    }

    assert_response :redirect
    assert_nil cookies["remember_user_token"]
  end
end
