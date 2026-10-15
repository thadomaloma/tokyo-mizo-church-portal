require "test_helper"

class ExpenseReceiptTest < ActionDispatch::IntegrationTest
  test "renders an A5 payment voucher with the amount in words and signature lines" do
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

    get admin_finance_transaction_voucher_path(transaction)

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
    assert_match(/width:\s*148mm/, response.body)
    assert_select "[data-voucher]", text: /Twelve thousand five hundred yen only/
    %w[Prepared Checked Approved Received].each do |label|
      assert_select "[data-voucher] p.label", text: "#{label} by"
    end
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

    get admin_finance_transaction_voucher_path(transaction)

    assert_redirected_to admin_finance_transactions_path(finance_unit_id: category.finance_unit_id)
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
