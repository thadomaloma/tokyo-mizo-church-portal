require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "an active member signs in and reaches the dashboard" do
    user = users(:one)

    visit root_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign In"

    assert_current_path authenticated_root_path
    assert_text "Chibai, #{user.name}. Lo kir leh rawh."
  end
end
