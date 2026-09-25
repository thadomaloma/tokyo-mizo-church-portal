require "test_helper"

class MobileNavigationTest < ActionDispatch::IntegrationTest
  test "president sees Reports as the mobile priority slot" do
    sign_in(users(:one)) # president

    get admin_root_path

    assert_response :success
    assert_select "nav.mobile-dock span", text: "Reports"
  end

  test "secretary sees Minutes as the mobile priority slot" do
    sign_in(users(:two)) # secretary

    get admin_root_path

    assert_response :success
    assert_select "nav.mobile-dock span", text: "Minutes"
  end

  test "treasurer sees Reports as the mobile priority slot" do
    treasurer = User.create!(name: "Global Treasurer", email: "global-treasurer@example.com", password: "secure-password", role: :treasurer)
    sign_in(treasurer, password: "secure-password")

    get admin_root_path

    assert_response :success
    assert_select "nav.mobile-dock span", text: "Reports"
  end

  test "an ordinary executive member sees Calendar as the mobile priority slot" do
    sign_in(users(:three)) # executive_member

    get admin_root_path

    assert_response :success
    assert_select "nav.mobile-dock span", text: "Calendar"
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

  test "the More menu always includes universally-viewable modules for every role" do
    sign_in(users(:three)) # executive_member

    get admin_root_path

    assert_response :success
    %w[Minutes Resolutions Calendar Members Reports].each do |label|
      assert_select "[role=dialog] a", text: /#{label}/
    end
  end

  test "mobile navigation never links to a route the signed-in user cannot actually load" do
    sign_in(users(:three)) # executive_member — the least-privileged non-guest role

    get admin_root_path
    assert_response :success

    [
      admin_meeting_minutes_path,
      admin_church_resolutions_path,
      admin_church_events_path,
      admin_users_path,
      admin_reports_path,
      admin_notifications_path,
      admin_profile_path
    ].each do |path|
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
