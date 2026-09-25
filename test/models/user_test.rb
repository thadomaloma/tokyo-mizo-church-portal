require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new accounts require a password of at least twelve characters" do
    user = User.new(
      name: "Short Password",
      email: "short-password@example.com",
      password: "too-short",
      role: :executive_member
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 12 characters)"
  end

  test "cannot delete a member who owns financial records" do
    user = users(:one)

    assert_not user.destroy
    assert_includes user.errors[:base], "Cannot delete record because dependent finance transactions exist"
    assert User.exists?(user.id)
  end

  test "deleting a notification actor keeps the notification and clears the actor" do
    user = User.create!(
      name: "Temporary President",
      email: "temporary-president@example.com",
      password: "secure-password",
      role: :president
    )
    notification = Notification.create!(
      actor: user,
      title: "Test",
      message: "Test notification",
      notification_type: "member",
      link: "/admin"
    )

    assert_no_difference -> { Notification.count } do
      user.destroy!
    end

    assert_nil notification.reload.actor
  end

  test "a finance title alone does not grant Main Church Finance access" do
    user = User.create!(
      name: "Unassigned Treasurer",
      email: "unassigned-treasurer@example.com",
      password: "secure-password",
      role: :treasurer
    )

    assert_not user.finance_access?
    assert_not user.can_view_finance_unit?(finance_units(:main))
    assert_not user.can_manage_finance_unit?(finance_units(:main))
  end
end
