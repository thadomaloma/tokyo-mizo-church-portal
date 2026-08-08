require "test_helper"

class DailyBibleVerseDisplayTest < ActionDispatch::IntegrationTest
  test "shows the local verse of the day in desktop and mobile headers" do
    sign_in_user

    get admin_root_path

    assert_response :success
    verse = DailyBibleVerse.for(Date.current)
    assert_select "[data-mobile-admin-header].fixed", count: 1
    assert_select "[data-desktop-admin-header].fixed", count: 1
    assert_select "[data-verse-of-the-day]", count: 2 do
      assert_select "p", text: /#{Regexp.escape(verse.text)}/
      assert_select "p", text: /#{Regexp.escape(verse.reference)}/
    end
  end

  private

  def sign_in_user
    post user_session_path, params: {
      user: {
        email: users(:one).email,
        password: "password"
      }
    }
  end
end
