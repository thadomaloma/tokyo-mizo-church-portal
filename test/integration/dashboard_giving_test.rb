require "test_helper"

class DashboardGivingTest < ActionDispatch::IntegrationTest
  test "dashboard giving totals use the shared tithe and offering matcher" do
    user = users(:one)
    tithe_category = FinanceCategory.create!(name: "Sawm a Pakhat", category_type: "income")
    offering_category = FinanceCategory.create!(name: "Thawh Hlawm", category_type: "income")
    other_category = FinanceCategory.create!(name: "Donation", category_type: "income")

    finance_transaction(tithe_category, user, 12_000)
    finance_transaction(offering_category, user, 8_000)
    finance_transaction(other_category, user, 5_000)

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }

    get admin_root_path

    assert_response :success
    assert_match "¥12,000", response.body
    assert_match "¥8,000", response.body
  end

  private

  def finance_transaction(category, user, amount)
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      recorded_by: user,
      amount: amount,
      transaction_date: Date.current,
      payment_location: "cash",
      description: category.name
    )
  end
end
