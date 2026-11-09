require "test_helper"

class CashBookImportTest < ActiveSupport::TestCase
  setup do
    @unit = finance_units(:main)
    @user = users(:one)
    FinanceCategory.install_system_catalog_for!(@unit)
    # 2026 starts with the 2025 money as opening entries: 300 cash + 700 bank.
    record("income", "opening_balance", 300, "2026-01-01", location: "cash")
    record("income", "opening_balance", 700, "2026-01-01", location: "bank")
    record("expense", "rent", 100, "2026-02-01", location: "bank")
  end

  test "imports the year, replaces the January opening entries and keeps today's balances" do
    before = balances

    assert import(csv(%w[2025-01-01 income opening_balance 400], %w[2025-03-02 income tithe 800],
                      %w[2025-03-31 expense rent 200])).run(commit: true)

    year = @unit.finance_transactions.where(transaction_date: Date.new(2025).all_year)
    assert_equal 4, year.count
    assert_equal 1_000, FinanceSummary.new(@unit).balance_on(Date.new(2025, 12, 31))
    assert_equal [ 700 ], year.transfer.pluck(:amount)
    assert_equal "EXP-2025-0001", year.expense.first.expense_voucher_number
    assert_not @unit.finance_transactions.income.where(transaction_date: Date.new(2026, 1, 1)).exists?
    assert_equal before, balances
  end

  test "a dry run saves nothing" do
    assert_no_difference -> { FinanceTransaction.count } do
      assert_not import(csv(%w[2025-01-01 income opening_balance 1000])).run
    end
  end

  test "refuses when the year does not end at the January opening balance" do
    error = assert_raises(CashBookImport::Error) { import(csv(%w[2025-01-01 income opening_balance 999])).run(commit: true) }

    assert_match "opening balance is ¥1,000 but the file ends 2025 at ¥999", error.message
    assert_equal 0, @unit.finance_transactions.where(transaction_date: Date.new(2025).all_year).count
  end

  test "refuses when the year already has entries" do
    record("income", "tithe", 5, "2025-06-01")

    error = assert_raises(CashBookImport::Error) { import(csv(%w[2025-01-01 income opening_balance 1000])).run(commit: true) }
    assert_match "already has 1 entries in 2025", error.message
  end

  test "refuses unknown categories and closed months" do
    assert_raises(CashBookImport::Error) { import(csv(%w[2025-01-01 income no_such_code 1000])).run }

    FinancePeriod.create!(finance_unit: @unit, year: 2026, month: 1, status: :closed, closed_at: Time.current, closed_by: @user)
    error = assert_raises(CashBookImport::Error) { import(csv(%w[2025-01-01 income opening_balance 1000])).run }
    assert_match "Reopen January 2026 first", error.message
  end

  private

  def import(path)
    CashBookImport.new(csv_path: path, finance_unit: @unit, recorded_by: @user)
  end

  def csv(*rows)
    file = Tempfile.new([ "cash_book", ".csv" ])
    file.write(([ %w[date type category amount note] ] + rows.map { |row| row + [ "note" ] }).map(&:to_csv).join)
    file.close
    (@files ||= []) << file
    file.path
  end

  def record(type, code, amount, date, location: "cash")
    @unit.finance_transactions.create!(
      transaction_type: type, finance_category: @unit.finance_categories.find_by!(code: code, category_type: type),
      amount: amount, transaction_date: Date.parse(date), payment_location: location, recorded_by: @user
    )
  end

  def balances
    summary = FinanceSummary.new(@unit)
    [ summary.current_balance, summary.cash_balance, summary.bank_balance ]
  end
end
