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

  test "the year comparison uses the same days of last year and leaves out opening balances" do
    unit = finance_units(:main)
    FinanceCategory.install_system_catalog_for!(unit)
    today = Date.new(2026, 3, 15)
    record = lambda do |type, code, amount, date|
      unit.finance_transactions.create!(transaction_type: type, amount: amount, transaction_date: date, payment_location: "cash",
                                        finance_category: unit.finance_categories.find_by!(code: code, category_type: type), recorded_by: users(:one))
    end
    record.call("income", "opening_balance", 9_000, Date.new(2025, 1, 1))
    record.call("income", "tithe", 1_000, Date.new(2025, 2, 2))
    record.call("income", "other_income", 500, Date.new(2025, 3, 20))  # after 15 March: not compared
    record.call("expense", "rent", 400, Date.new(2025, 3, 1))
    record.call("income", "offering", 1_500, Date.new(2026, 2, 1))
    record.call("expense", "rent", 200, Date.new(2026, 3, 1))

    comparison = FinanceSummary.new(unit, today: today).year_comparison

    assert_equal({ income: 1_500, expense: 200, giving: 1_500 }, comparison[:current])
    assert_equal({ income: 1_000, expense: 400, giving: 1_000 }, comparison[:previous])
    assert_equal [ 0, 1_500, 0 ], comparison[:income_by_month].first(3)
    assert_nil comparison[:income_by_month][3]
    assert_equal [ 0, 1_000, 500 ], comparison[:previous_income_by_month].first(3)
  end
end
