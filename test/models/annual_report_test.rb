require "test_helper"

class AnnualReportTest < ActiveSupport::TestCase
  setup do
    @unit = finance_units(:main)
    FinanceCategory.install_system_catalog_for!(@unit)
    record("income", "opening_balance", 1_000, Date.new(2025, 1, 1))
    record("income", "tithe", 400, Date.new(2025, 2, 2))
    record("expense", "rent", 150, Date.new(2025, 3, 1))
    record("income", "tithe", 500, Date.new(2026, 2, 1))
    record("expense", "rent", 200, Date.new(2026, 3, 1))
    record("expense", "rent", 999, Date.new(2026, 4, 1)) # after "today" below
    FinanceBudget.create!(finance_unit: @unit, year: 2026).update_amounts({ category("expense", "rent").id => 800 }, [ category("expense", "rent") ])
  end

  test "a past year: opening balances count towards the opening, not income" do
    report = AnnualReport.new(@unit, 2025, today: Date.new(2026, 3, 15))

    assert_not report.partial?
    assert_equal [ 1_000, 400, 150, 1_250 ], [ report.opening_balance, report.income, report.expense, report.closing_balance ]
    assert_equal [ "Tithe (Sawm a Pakhat)" ], report.income_lines.map(&:name)
    assert_equal [ "January", 0, 0, 0, 1_000 ], report.monthly_rows.first
    assert_equal 1_250, report.monthly_rows.last.last
    assert_equal 12, report.monthly_rows.size
  end

  test "the current year runs to today and compares with the same days of last year" do
    report = AnnualReport.new(@unit, 2026, today: Date.new(2026, 3, 15))

    assert report.partial?
    assert_equal "2026 (to 15 March)", report.label
    assert_equal [ 1_250, 500, 200, 1_550 ], [ report.opening_balance, report.income, report.expense, report.closing_balance ]
    assert_equal [ 400, 150 ], [ report.previous_income, report.previous_expense ]
    rent = report.expense_lines.find { |line| line.name.start_with?("Church Rent") }
    assert_equal [ 200, 150, 800, 25 ], [ rent.amount, rent.previous, rent.budget, rent.budget_used ]
    assert_equal 3, report.monthly_rows.size
  end

  test "renders a PDF" do
    pdf = AnnualReportPdf.new(AnnualReport.new(@unit, 2026, today: Date.new(2026, 3, 15))).render

    assert pdf.start_with?("%PDF")
  end

  private

  def category(type, code)
    @unit.finance_categories.find_by!(code: code, category_type: type)
  end

  def record(type, code, amount, date)
    @unit.finance_transactions.create!(transaction_type: type, finance_category: category(type, code), amount: amount,
                                       transaction_date: date, payment_location: "cash", recorded_by: users(:one))
  end
end
