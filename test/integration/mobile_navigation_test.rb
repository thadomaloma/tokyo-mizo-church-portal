require "test_helper"

class MobileNavigationTest < ActionDispatch::IntegrationTest
  test "a user with finance access sees Home, Finance and Reports in the dock" do
    sign_in(users(:one)) # president

    get admin_root_path

    assert_response :success
    %w[Home Finance Reports].each do |label|
      assert_select "nav.mobile-dock span", text: label
    end
  end

  test "a user without finance access only sees Home in the dock" do
    sign_in(users(:three)) # executive_member, no unit assignment

    get admin_root_path

    assert_response :success
    assert_select "nav.mobile-dock span", text: "Home"
    assert_select "nav.mobile-dock span", text: "Finance", count: 0
    assert_select "nav.mobile-dock span", text: "Reports", count: 0
  end

  test "the More menu offers Finance Access management to a super admin" do
    sign_in(users(:one)) # president, super_admin

    get admin_root_path

    assert_select "[role=dialog] a", text: /Finance Access/
  end

  test "the More menu hides Finance Access management from a non-super-admin" do
    sign_in(users(:three)) # executive_member, not super_admin

    get admin_root_path

    assert_select "[role=dialog] a", text: /Finance Access/, count: 0
  end

  test "navigation no longer links to removed secretary modules" do
    sign_in(users(:one))

    get admin_root_path

    assert_response :success
    %w[Minutes Resolutions Letters Calendar Notification].each do |label|
      assert_no_match(/>\s*#{label}/, response.body)
    end
  end

  test "mobile navigation never links to a route the signed-in user cannot actually load" do
    sign_in(users(:three)) # executive_member — the least-privileged role

    get admin_root_path
    assert_response :success

    [ admin_users_path, admin_profile_path ].each do |path|
      get path
      assert_response :success, "expected #{path} to be reachable for an executive member, as the More menu links to it"
    end
  end

  test "dashboard is unreachable without authentication" do
    get admin_root_path

    assert_redirected_to new_user_session_path
  end

  private

  def sign_in(user, password: "password")
    post user_session_path, params: { user: { email: user.email, password: password } }
  end
end
