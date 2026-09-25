require "test_helper"

class FinanceUnitTest < ActiveSupport::TestCase
  test "ships the required church, department, and fund ledgers" do
    assert_equal "Main Church Finance", FinanceUnit.main.name
    assert_equal %w[
      main-church-finance
      naupang-department
      thalai-department
      hmeichhe-department
      building-sum
      mission-sum
    ], FinanceUnit.ordered.pluck(:slug)
  end

  test "main church finance cannot be disabled" do
    main = FinanceUnit.main
    main.active = false

    assert_not main.valid?
    assert_includes main.errors[:active], "must remain enabled for the main church ledger"
  end

  test "finance unit slug is immutable" do
    unit = finance_units(:naupang)
    unit.slug = "children-department"

    assert_not unit.valid?
    assert_includes unit.errors[:slug], "cannot be changed after the finance unit is created"
  end

  test "a department with a finance secretary cannot become a treasurer-only fund" do
    unit = finance_units(:naupang)
    FinanceUnitMembership.create!(
      finance_unit: unit,
      user: users(:three),
      role: "finance_secretary"
    )

    unit.unit_type = "fund"

    assert_not unit.valid?
    assert_includes unit.errors[:unit_type], "cannot be changed to a fund while a Finance Secretary is assigned"
  end
end
