require "test_helper"

class FinanceBudgetTest < ActiveSupport::TestCase
  setup do
    @budget = FinanceBudget.new(finance_unit: finance_units(:main), year: 2026)
    @categories = [ finance_categories(:two) ]
  end

  test "update_amounts saves planned amounts and drops cleared ones" do
    assert @budget.update_amounts({ finance_categories(:two).id => 90_000 }, @categories)
    assert_equal 90_000, @budget.reload.planned_total

    assert @budget.update_amounts({}, @categories)
    assert_equal 0, @budget.reload.planned_total
  end

  test "update_amounts rejects amounts that are not whole yen" do
    assert_not @budget.update_amounts({ finance_categories(:two).id => :invalid }, @categories)
    assert_not @budget.persisted?
    assert_includes @budget.errors.full_messages, "Amounts must be whole numbers (yen)."
  end
end
