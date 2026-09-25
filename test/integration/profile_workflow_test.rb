require "test_helper"

class ProfileWorkflowTest < ActionDispatch::IntegrationTest
  test "any authenticated user can open their profile and see notification settings, regardless of role" do
    ordinary_member = users(:three)
    sign_in(ordinary_member)

    get admin_profile_path

    assert_response :success
    assert_includes response.body, "Push Notifications"
    assert_includes response.body, ordinary_member.name
  end

  test "profile requires authentication" do
    get admin_profile_path

    assert_redirected_to new_user_session_path
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
