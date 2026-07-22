require "test_helper"

class FinanceTransactionsSummaryFilterTest < ActionDispatch::IntegrationTest
  test "finance management filters monthly income and expense summary cards separately" do
    sign_in_user
    income_category = FinanceCategory.create!(name: "June Income", category_type: "income")
    expense_category = FinanceCategory.create!(name: "June Expense", category_type: "expense")

    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: income_category,
      recorded_by: users(:one),
      amount: 12_000,
      transaction_date: Date.new(2026, 6, 5),
      payment_location: "cash",
      description: "June income"
    )
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 7_500,
      transaction_date: Date.new(2026, 7, 6),
      payment_location: "cash",
      description: "July expense"
    )
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: income_category,
      recorded_by: users(:one),
      amount: 99_000,
      transaction_date: Date.new(2026, 5, 5),
      payment_location: "cash",
      description: "May income"
    )
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 88_000,
      transaction_date: Date.new(2026, 6, 6),
      payment_location: "cash",
      description: "June expense"
    )

    get admin_finance_transactions_path(
      income_summary_year: 2026,
      income_summary_month: 6,
      ledger_filter: "income"
    )

    assert_response :success
    assert_select "select[name='income_summary_year'] option[selected='selected'][value='2026']"
    assert_select "select[name='income_summary_month'] option[selected='selected'][value='6']", text: "June"
    assert_includes response.body, "Monthly Income"
    assert_includes response.body, "June 2026"
    assert_includes response.body, "¥12,000"
    assert_includes response.body, "Income Transactions"
    assert_includes response.body, "Income records for June 2026."
    assert_includes response.body, "June income"
    assert_not_includes response.body, "June expense"
    assert_not_includes response.body, "July expense"

    get admin_finance_transactions_path(
      expense_summary_year: 2026,
      expense_summary_month: 7,
      ledger_filter: "expense"
    )

    assert_response :success
    assert_select "select[name='expense_summary_year'] option[selected='selected'][value='2026']"
    assert_select "select[name='expense_summary_month'] option[selected='selected'][value='7']", text: "July"
    assert_includes response.body, "Monthly Expense"
    assert_includes response.body, "July 2026"
    assert_includes response.body, "¥7,500"
    assert_includes response.body, "Expense Transactions"
    assert_includes response.body, "Expense records for July 2026."
    assert_includes response.body, "July expense"
    assert_not_includes response.body, "June income"
    assert_not_includes response.body, "June expense"
  end

  private

  def sign_in_user
    post user_session_path, params: {
      user: {
        email: users(:one).email,
        password: "password"
      }
    }
  end
end
