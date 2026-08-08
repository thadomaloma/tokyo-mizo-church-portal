require "test_helper"

class ExpenseReceiptTest < ActionDispatch::IntegrationTest
  test "renders a compact branded expense receipt without sharing controls" do
    sign_in_user
    category = FinanceCategory.create!(name: "Community Event", category_type: "expense")
    transaction = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      recorded_by: users(:one),
      amount: 12_500,
      transaction_date: Date.new(2026, 8, 8),
      payment_location: "bank",
      description: "Venue deposit"
    )

    get receipt_admin_finance_transaction_path(transaction)

    assert_response :success
    assert_select "h1", text: "Tokyo Mizo Church"
    assert_select "p", text: "Expense Receipt"
    assert_select "p", text: "¥12,500"
    assert_select "p", text: /#{Regexp.escape(transaction.expense_voucher_number)}/
    assert_select "p", text: "Venue deposit"
    assert_select "p", text: "Community Event", minimum: 1
    assert_select "button[data-controller='print'][data-action='click->print#print']", text: /Print/
    assert_not_includes response.body, "onclick=\"window.print()\""
    assert_select "[data-verse-of-the-day]", count: 0
    assert_match(/size:\s*A5 portrait/, response.body)
    assert_match(/width:\s*132mm/, response.body)
    assert_match(/\.receipt-finance-grid\s*\{[^}]*display:\s*grid/m, response.body)
  end

  test "does not render a receipt for an income transaction" do
    sign_in_user
    category = FinanceCategory.create!(name: "Donation", category_type: "income")
    transaction = FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      recorded_by: users(:one),
      amount: 5_000,
      transaction_date: Date.new(2026, 8, 8),
      payment_location: "cash",
      description: "Offering"
    )

    get receipt_admin_finance_transaction_path(transaction)

    assert_redirected_to admin_finance_transactions_path
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
