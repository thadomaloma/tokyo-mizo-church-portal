require "test_helper"

class FinancePeriodTest < ActiveSupport::TestCase
  test "find_or_open returns an unsaved open period when none exists" do
    period = FinancePeriod.find_or_open(finance_units(:main), 2026, 5)

    assert period.new_record?
    assert period.open?
  end

  test "close! records who closed the period and when" do
    period = FinancePeriod.find_or_open(finance_units(:main), 2026, 5)

    period.close!(users(:one))

    assert period.closed?
    assert_equal users(:one), period.closed_by
    assert period.closed_at.present?
  end

  test "reopen! records who reopened the period and when" do
    period = FinancePeriod.find_or_open(finance_units(:main), 2026, 5)
    period.close!(users(:one))

    period.reopen!(users(:two))

    assert period.open?
    assert_equal users(:two), period.reopened_by
    assert period.reopened_at.present?
  end

  test "rejects a duplicate year/month for the same finance unit" do
    FinancePeriod.create!(finance_unit: finance_units(:main), year: 2026, month: 5, status: :open)
    duplicate = FinancePeriod.new(finance_unit: finance_units(:main), year: 2026, month: 5, status: :open)

    assert_not duplicate.valid?
  end

  test "allows the same year/month across different finance units" do
    FinancePeriod.create!(finance_unit: finance_units(:main), year: 2026, month: 5, status: :open)
    other_unit = FinancePeriod.new(finance_unit: finance_units(:building), year: 2026, month: 5, status: :open)

    assert other_unit.valid?
  end
end
