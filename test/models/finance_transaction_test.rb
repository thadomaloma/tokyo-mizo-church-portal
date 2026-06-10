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
end
