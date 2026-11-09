require "test_helper"

class SettingsWorkflowTest < ActionDispatch::IntegrationTest
  test "any authenticated user can open settings and see their own account" do
    ordinary_member = users(:three)
    sign_in(ordinary_member)

    get admin_settings_path

    assert_response :success
    assert_includes response.body, ordinary_member.name
    assert_select "[data-settings-users]", count: 0
    assert_select "[data-app-about]", text: /Version\s*#{Regexp.escape(Rails.configuration.x.app_version)}.*Developer\s*Maloma Thado/m
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


  test "settings has no logout button; logout stays in the account menu" do
    sign_in(users(:three))

    get admin_settings_path

    assert_select "main form[action=?]", destroy_user_session_path, count: 0
    assert_select "[data-dropdown-target=menu] form[action=?]", destroy_user_session_path
    assert_select "a[href=?]", edit_admin_password_path, text: /Change password/
  end

  test "a user changes their own password and stays signed in" do
    user = users(:three)
    sign_in(user)

    patch admin_password_path, params: { user: { current_password: "password", password: "new-password-123", password_confirmation: "new-password-123" } }

    assert_redirected_to admin_settings_path
    assert user.reload.valid_password?("new-password-123")
    get admin_settings_path
    assert_response :success
  end

  test "changing the password needs the right current password and a new one" do
    user = users(:three)
    sign_in(user)

    patch admin_password_path, params: { user: { current_password: "wrong", password: "new-password-123", password_confirmation: "new-password-123" } }
    assert_response :unprocessable_entity
    assert_includes page_text, "Current password is invalid"

    patch admin_password_path, params: { user: { current_password: "password", password: "", password_confirmation: "" } }
    assert_response :unprocessable_entity
    assert_includes page_text, "Password can't be blank"

    patch admin_password_path, params: { user: { current_password: "password", password: "new-password-123", password_confirmation: "different-123" } }
    assert_response :unprocessable_entity

    assert user.reload.valid_password?("password")
  end


  test "About shows when the running copy was updated" do
    AppBuild.instance_variable_set(:@current, AppBuild.new("aa20ff9d3c1e2f\n2026-11-09T01:30:00Z\n"))
    sign_in(users(:three))

    get admin_settings_path

    assert_select "[data-app-version]", text: /#{Regexp.escape(Rails.configuration.x.app_version)}\s*· Updated 9 Nov 2026 \(aa20ff9\)/
  ensure
    AppBuild.instance_variable_set(:@current, nil)
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
