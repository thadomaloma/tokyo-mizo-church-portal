require "test_helper"

class FinanceUnitMembershipTest < ActiveSupport::TestCase
  test "treasurer and finance secretary can manage an assigned unit" do
    user = users(:three)
    unit = finance_units(:naupang)

    membership = FinanceUnitMembership.create!(finance_unit: unit, user: user, role: "treasurer")
    assert membership.manager?
    assert user.can_manage_finance_unit?(unit)

    membership.update!(role: "finance_secretary")
    assert membership.manager?
    assert user.can_manage_finance_unit?(unit)
  end

  test "viewer can read but cannot manage an assigned unit" do
    user = users(:three)
    unit = finance_units(:thalai)
    FinanceUnitMembership.create!(finance_unit: unit, user: user, role: "viewer")

    assert user.can_view_finance_unit?(unit)
    assert_not user.can_manage_finance_unit?(unit)
  end

  test "a member has only one role per finance unit" do
    existing = FinanceUnitMembership.create!(
      finance_unit: finance_units(:building),
      user: users(:three),
      role: "treasurer"
    )
    duplicate = FinanceUnitMembership.new(
      finance_unit: existing.finance_unit,
      user: existing.user,
      role: "viewer"
    )

    assert_not duplicate.valid?
  end

  test "fund units allow a treasurer but not a finance secretary" do
    membership = FinanceUnitMembership.new(
      finance_unit: finance_units(:mission),
      user: users(:three),
      role: "finance_secretary"
    )

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not available for this finance unit"

    membership.role = "treasurer"
    assert membership.valid?
  end

  test "a finance unit has only one treasurer and one finance secretary" do
    FinanceUnitMembership.create!(finance_unit: finance_units(:naupang), user: users(:one), role: "treasurer")
    duplicate = FinanceUnitMembership.new(finance_unit: finance_units(:naupang), user: users(:three), role: "treasurer")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:role], "already has an assigned Treasurer"
  end
end
