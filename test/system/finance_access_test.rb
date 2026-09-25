require "application_system_test_case"

class FinanceAccessTest < ApplicationSystemTestCase
  test "president can understand and use finance assignments on desktop and mobile" do
    sign_in(users(:one))

    visit admin_finance_units_path

    assert_text "Finance Access"
    assert_text "Permission Workflow"
    assert_text "Main Church Finance"
    assert_field "finance-unit-#{finance_units(:main).id}-treasurer"
    assert_button "Save Treasurer", minimum: 1

    select_ids = page.all("select[id^='finance-unit-']").map { |select| select[:id] }
    assert_equal select_ids.uniq, select_ids
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

    page.current_window.resize_to(390, 844)
    assert_text "Finance Access"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end

  private

  def sign_in(user)
    visit root_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign In"
    assert_current_path authenticated_root_path
    assert_text "Chibai, #{user.name}. Lo kir leh rawh."
  end
end
