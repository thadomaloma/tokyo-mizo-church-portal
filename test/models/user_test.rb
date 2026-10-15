require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new accounts require a password of at least twelve characters" do
    user = User.new(
      name: "Short Password",
      email: "short-password@example.com",
      password: "too-short",
      role: :finance_secretary
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

  test "only four church offices exist and the chairman and secretary administer" do
    assert_equal [ [ "Chairman", "chairman" ], [ "Secretary", "secretary" ], [ "Treasurer", "treasurer" ], [ "Finance Secretary", "finance_secretary" ] ],
                 User.role_options
    assert User.new(role: :chairman).super_admin?
    assert User.new(role: :secretary).super_admin?
    assert_not User.new(role: :treasurer).super_admin?
    assert_not User.new(role: "president", name: "Old", email: "old@example.com", password: "secure-password").valid?
  end
end
