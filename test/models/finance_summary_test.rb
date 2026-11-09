require "test_helper"

class FinanceSummaryTest < ActiveSupport::TestCase
  test "the balance chart ends on the total balance, entries dated later this month included" do
    unit = finance_units(:main)
    today = Date.new(2026, 11, 9)
    [ [ "income", 5_000, today - 40, finance_categories(:one) ],
      [ "expense", 1_200, today, finance_categories(:two) ],
      [ "expense", 300, today + 5, finance_categories(:two) ] ].each do |type, amount, date, category|
      unit.finance_transactions.create!(transaction_type: type, amount: amount, transaction_date: date,
                                        payment_location: "cash", finance_category: category, recorded_by: users(:one))
    end

    summary = FinanceSummary.new(unit, today: today)
    history = summary.balance_history(3)

    assert_equal summary.current_balance, history.last[:balance]
    assert_equal 5_000, history[-2][:balance]
  end
end
