require "test_helper"

class SundayOfferingTest < ActiveSupport::TestCase
  setup do
    @unit = finance_units(:main)
    @category = finance_categories(:one)
  end

  test "records one income per counted category, all or nothing" do
    offering = SundayOffering.new(finance_unit: @unit, recorded_by: users(:one), transaction_date: Date.new(2026, 10, 11),
                                  counted_by: "A, B", amounts: { @category.id.to_s => "7,500" })

    assert_difference -> { @unit.finance_transactions.income.count }, 1 do
      assert offering.save
    end
    assert_equal 7_500, offering.total
    assert_equal "Sunday offering · Counted by: A, B", @unit.finance_transactions.income.last.description
  end

  test "needs at least one whole-yen amount" do
    assert_not SundayOffering.new(finance_unit: @unit, recorded_by: users(:one), amounts: {}).valid?
    assert_not SundayOffering.new(finance_unit: @unit, recorded_by: users(:one), amounts: { @category.id.to_s => "abc" }).valid?
  end

  test "defaults to the most recent Sunday" do
    assert_predicate SundayOffering.new(finance_unit: @unit).transaction_date, :sunday?
  end
end
