require "test_helper"

class UsersWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @current_user = users(:one)
    post user_session_path, params: {
      user: { email: @current_user.email, password: "password" }
    }
  end

  test "a super admin can create a member with an approved role" do
    assert_difference -> { User.count }, 1 do
      post admin_users_path, params: {
        user: {
          name: "New Treasurer",
          email: "new-treasurer@example.com",
          role: "treasurer",
          active: true,
          password: "secure-password",
          password_confirmation: "secure-password"
        }
      }
    end

    assert_equal "treasurer", User.find_by!(email: "new-treasurer@example.com").role
    assert_redirected_to admin_users_path
  end

  test "a member cannot delete their own signed in account" do
    assert_no_difference -> { User.count } do
      delete admin_user_path(@current_user)
    end

    assert_redirected_to admin_users_path
    assert_equal "You cannot delete your own account.", flash[:alert]
  end

  test "a member who owns records is retained instead of causing a foreign key error" do
    member = users(:two)

    assert_no_difference -> { User.count } do
      delete admin_user_path(member)
    end

    assert_redirected_to admin_users_path
    assert User.exists?(member.id)
    assert_match(/Cannot delete record/, flash[:alert])
  end
end
