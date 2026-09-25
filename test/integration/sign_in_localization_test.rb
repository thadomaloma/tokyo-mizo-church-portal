require "test_helper"

class SignInLocalizationTest < ActionDispatch::IntegrationTest
  test "sign in page uses clear Mizo labels" do
    get new_user_session_path

    assert_response :success
    assert_select "h1", text: "Welcome Back"
    assert_select "label", text: "Email Address"
    assert_select "label", text: "Password"
    assert_select "label", text: "Remember me"
    assert_select "input[type='submit'][value='Sign In']"
    assert_match(/Forgot your password\?/, response.body)
    assert_no_match(/Sign in to continue/, response.body)
  end

  test "invalid sign in message is shown in Mizo" do
    post user_session_path, params: {
      user: { email: "unknown@example.com", password: "wrong-password" }
    }

    assert_response :unprocessable_entity
    assert_match(/Email address emaw password a dik lo\./, response.body)
  end

  test "password recovery page uses Mizo instructions" do
    get new_user_password_path

    assert_response :success
    assert_select "h1", text: "Forgot Password?"
    assert_select "input[type='submit'][value='Send Reset Instructions']"
    assert_match(/Back to Sign In/, response.body)
  end
end
