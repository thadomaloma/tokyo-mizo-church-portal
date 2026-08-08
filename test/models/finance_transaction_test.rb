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

    assert_equal 1, first.voucher_number
    assert_equal "EXP-0001", first.expense_voucher_number
    assert_equal 2, second.voucher_number
    assert_equal "EXP-0002", second.expense_voucher_number
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
    assert_includes transaction.errors[:finance_category], "must match the transaction type"
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
end
