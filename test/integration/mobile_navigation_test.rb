require "test_helper"

class MobileNavigationTest < ActionDispatch::IntegrationTest
  test "a finance user gets Sumvon-style navigation with an Add button" do
    sign_in(users(:one)) # chairman

    get admin_root_path

    assert_response :success
    %w[Home Transactions Budget Reports].each do |label|
      assert_select "nav.mobile-dock span", text: label
    end
    assert_select "nav.mobile-dock a[aria-label='Add transaction']"
    %w[Home Transactions Budget Reports Accounts Settings].each do |label|
      assert_select ".admin-sidebar nav a", text: /#{label}/
    end
  end

  test "a user without finance access only sees Home and Settings" do
    sign_in(users(:three)) # finance secretary title, no unit assignment

    get admin_root_path

    assert_response :success
    assert_select "nav.mobile-dock span", text: "Home"
    assert_select "nav.mobile-dock span", text: "Settings"
    assert_select "nav.mobile-dock span", text: "Transactions", count: 0
    assert_select "a[aria-label='Add transaction']", count: 0
  end

  test "navigation no longer links to removed modules" do
    sign_in(users(:one))

    get admin_root_path

    assert_response :success
    %w[Minutes Resolutions Letters Calendar Members Notification].each do |label|
      assert_no_match(/>\s*#{label}/, response.body)
    end
  end

  test "every navigation destination loads for a finance user" do
    sign_in(users(:one))

    [ admin_finance_transactions_path, admin_budgets_path, admin_finance_period_path(Date.current.year, Date.current.month), admin_finance_report_path, admin_accounts_path, admin_settings_path ].each do |path|
      get path
      follow_redirect! if response.redirect?
      assert_response :success, "expected #{path} to load"
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
