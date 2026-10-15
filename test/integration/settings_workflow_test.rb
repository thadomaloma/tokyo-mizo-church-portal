require "test_helper"

class SettingsWorkflowTest < ActionDispatch::IntegrationTest
  test "any authenticated user can open settings and see their own account" do
    ordinary_member = users(:three)
    sign_in(ordinary_member)

    get admin_settings_path

    assert_response :success
    assert_includes response.body, ordinary_member.name
    assert_select "[data-settings-users]", count: 0
    assert_select "[data-app-about]", text: /Version\s*2\.0.*Developer\s*Maloma Thado/m
  end

  test "a super admin manages users from settings" do
    sign_in(users(:one))

    get admin_settings_path

    assert_response :success
    assert_select "[data-settings-users] li", count: User.count
    assert_select "a[href=?]", new_admin_user_path
    assert_select "a[href=?]", admin_finance_units_path
  end

  test "users other than super admins cannot open user management" do
    sign_in(users(:three))

    get new_admin_user_path

    assert_redirected_to admin_root_path
  end

  test "settings requires authentication" do
    get admin_settings_path

    assert_redirected_to new_user_session_path
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
