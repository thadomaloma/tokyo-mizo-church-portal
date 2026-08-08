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

  test "an invalid member role returns a form error instead of a bad request" do
    assert_no_difference -> { User.count } do
      post admin_users_path, params: {
        user: {
          name: "No Role Member",
          email: "no-role@example.com",
          role: "",
          active: true,
          password: "secure-password",
          password_confirmation: "secure-password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Role is not included in the approved roles"
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

  test "a super admin cannot deactivate their own signed in account" do
    patch admin_user_path(@current_user), params: {
      user: {
        name: @current_user.name,
        email: @current_user.email,
        role: @current_user.role,
        active: false
      }
    }

    assert_response :unprocessable_entity
    assert @current_user.reload.active?
    assert_includes response.body, "You cannot deactivate or remove administrator access"
  end

  test "a super admin cannot remove their own administrator role" do
    patch admin_user_path(@current_user), params: {
      user: {
        name: @current_user.name,
        email: @current_user.email,
        role: "executive_member",
        active: true
      }
    }

    assert_response :unprocessable_entity
    assert @current_user.reload.super_admin?
    assert_includes response.body, "You cannot deactivate or remove administrator access"
  end
end
