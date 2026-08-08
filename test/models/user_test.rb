require "test_helper"

class UserTest < ActiveSupport::TestCase
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
      password: "password",
      role: :president
    )
    notification = Notification.create!(
      actor: user,
      title: "Test",
      message: "Test notification",
      notification_type: "test",
      link: "/admin"
    )

    assert_no_difference -> { Notification.count } do
      user.destroy!
    end

    assert_nil notification.reload.actor
  end
end
