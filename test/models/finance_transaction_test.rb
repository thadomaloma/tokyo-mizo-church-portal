require "test_helper"

class FinanceTransactionTest < ActiveSupport::TestCase
  test "assigns sequential voucher numbers to expense transactions" do
    category = FinanceCategory.create!(name: "Utilities", category_type: "expense")
    user = users(:one)

    first = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      recorded_by: user,
      amount: 1_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )

    second = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      recorded_by: user,
      amount: 2_000,
      transaction_date: Date.current,
      payment_location: "bank"
    )

    year = Date.current.year

    assert_equal 1, first.voucher_number
    assert_equal "EXP-#{year}-0001", first.expense_voucher_number
    assert_equal 2, second.voucher_number
    assert_equal "EXP-#{year}-0002", second.expense_voucher_number
  end

  test "does not assign voucher numbers to income transactions" do
    category = FinanceCategory.create!(name: "Tithe", category_type: "income")
    user = users(:one)

    transaction = FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      recorded_by: user,
      amount: 1_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )

    assert_nil transaction.voucher_number
    assert_nil transaction.expense_voucher_number
  end

  test "rejects a category from the opposite transaction type" do
    expense_category = FinanceCategory.create!(name: "Rent", category_type: "expense")

    transaction = FinanceTransaction.new(
      transaction_type: "income",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 1_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:finance_category], "must match the transaction type and finance unit"
  end

  test "clears an expense voucher number when changed to income" do
    expense_category = FinanceCategory.create!(name: "Equipment", category_type: "expense")
    income_category = FinanceCategory.create!(name: "Donation", category_type: "income")
    transaction = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 3_000,
      transaction_date: Date.current,
      payment_location: "bank"
    )

    assert transaction.voucher_number.present?

    transaction.update!(transaction_type: "income", finance_category: income_category)

    assert_nil transaction.voucher_number
  end

  test "expense voucher sequences are independent for each finance unit" do
    main_category = FinanceCategory.create!(
      name: "Main Expense",
      category_type: "expense",
      finance_unit: finance_units(:main)
    )
    building_category = FinanceCategory.create!(
      name: "Building Expense",
      category_type: "expense",
      finance_unit: finance_units(:building)
    )

    main_expense = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: main_category,
      finance_unit: finance_units(:main),
      recorded_by: users(:one),
      amount: 1_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )
    building_expense = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: building_category,
      finance_unit: finance_units(:building),
      recorded_by: users(:one),
      amount: 2_000,
      transaction_date: Date.current,
      payment_location: "bank"
    )

    assert_equal 1, main_expense.voucher_number
    assert_equal 1, building_expense.voucher_number
  end

  test "an expense voucher number is not reused after the latest expense is deleted" do
    category = FinanceCategory.create!(name: "Sequence Expense", category_type: "expense")
    first = create_expense(category, 1_000)
    second = create_expense(category, 2_000)

    second.destroy!
    replacement = create_expense(category, 3_000)

    assert_equal 1, first.voucher_number
    assert_equal 3, replacement.voucher_number
  end

  test "voucher numbering restarts per year without colliding across years" do
    category = FinanceCategory.create!(name: "Year Scoped Expense", category_type: "expense")

    this_year = create_expense(category, 1_000, transaction_date: Date.new(Date.current.year, 3, 1))
    last_year = create_expense(category, 2_000, transaction_date: Date.new(Date.current.year - 1, 3, 1))
    this_year_again = create_expense(category, 3_000, transaction_date: Date.new(Date.current.year, 6, 1))

    assert_equal 1, this_year.voucher_number
    assert_equal 1, last_year.voucher_number
    assert_equal 2, this_year_again.voucher_number
    assert_equal Date.current.year, this_year.voucher_year
    assert_equal Date.current.year - 1, last_year.voucher_year
  end

  test "voucher number is not reused after deletion even across an out-of-order backdated entry" do
    category = FinanceCategory.create!(name: "Backdate Expense", category_type: "expense")

    first = create_expense(category, 1_000, transaction_date: Date.new(Date.current.year, 3, 1))
    second = create_expense(category, 2_000, transaction_date: Date.new(Date.current.year, 4, 1))
    first.destroy!

    create_expense(category, 3_000, transaction_date: Date.new(Date.current.year - 1, 1, 1))
    fourth = create_expense(category, 4_000, transaction_date: Date.new(Date.current.year, 5, 1))

    assert_equal 3, fourth.voucher_number
    assert_not_equal second.voucher_number, first.voucher_number
  end

  private

  def create_expense(category, amount, transaction_date: Date.current)
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      recorded_by: users(:one),
      amount: amount,
      transaction_date: transaction_date,
      payment_location: "cash"
    )
  end
end
