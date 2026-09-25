require "test_helper"

class FinancePeriodsWorkflowTest < ActionDispatch::IntegrationTest
  test "manager can close a month, editing is blocked, then reopen restores editing" do
    sign_in(users(:one))
    category = create_system_category("Closing Flow Category")
    transaction = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      finance_unit: finance_units(:main),
      recorded_by: users(:one),
      amount: 1_000,
      transaction_date: Date.new(2026, 4, 10),
      payment_location: "cash"
    )

    get admin_finance_period_path(2026, 4, finance_unit_id: finance_units(:main).id)
    assert_response :success
    assert_select "button", text: /Close Month/

    patch admin_close_finance_period_path(2026, 4, finance_unit_id: finance_units(:main).id)
    assert_redirected_to admin_finance_period_path(2026, 4, finance_unit_id: finance_units(:main).id)
    assert FinancePeriod.find_by(finance_unit: finance_units(:main), year: 2026, month: 4).closed?

    patch admin_finance_transaction_path(transaction), params: {
      finance_unit_id: finance_units(:main).id,
      finance_transaction: { transaction_type: "expense", amount: 5_000, transaction_date: "2026-04-10", payment_location: "cash" }
    }
    assert_response :unprocessable_entity
    assert_equal 1_000, transaction.reload.amount

    delete admin_finance_transaction_path(transaction), params: { finance_unit_id: finance_units(:main).id }
    assert_redirected_to admin_finance_transactions_path(finance_unit_id: finance_units(:main).id)
    assert FinanceTransaction.exists?(transaction.id)

    patch admin_reopen_finance_period_path(2026, 4, finance_unit_id: finance_units(:main).id)
    assert FinancePeriod.find_by(finance_unit: finance_units(:main), year: 2026, month: 4).open?

    patch admin_finance_transaction_path(transaction), params: {
      finance_unit_id: finance_units(:main).id,
      finance_transaction: { transaction_type: "expense", amount: 5_000, transaction_date: "2026-04-10", payment_location: "cash" }
    }
    assert_redirected_to admin_finance_transactions_path(finance_unit_id: finance_units(:main).id)
    assert_equal 5_000, transaction.reload.amount
  end

  test "a new transaction cannot be created dated inside a closed month" do
    sign_in(users(:one))
    category = create_system_category("Blocked Create Category")
    FinancePeriod.create!(finance_unit: finance_units(:main), year: 2026, month: 2, status: :closed, closed_at: Time.current, closed_by: users(:one))

    assert_no_difference "FinanceTransaction.count" do
      post admin_finance_transactions_path, params: {
        finance_unit_id: finance_units(:main).id,
        finance_transaction: {
          transaction_type: "expense",
          finance_category_id: category.id,
          amount: 1_000,
          transaction_date: "2026-02-15",
          payment_location: "cash"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "read-only role cannot close or reopen a month" do
    sign_in(users(:three))

    patch admin_close_finance_period_path(2026, 4, finance_unit_id: finance_units(:main).id)
    assert_redirected_to admin_root_path
    assert_not FinancePeriod.exists?(finance_unit: finance_units(:main), year: 2026, month: 4)
  end

  test "closing is blocked when an expense transaction is missing a voucher number" do
    sign_in(users(:one))
    category = create_system_category("No Voucher Category")
    transaction = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      finance_unit: finance_units(:main),
      recorded_by: users(:one),
      amount: 1_000,
      transaction_date: Date.new(2026, 6, 5),
      payment_location: "cash"
    )
    transaction.update_column(:voucher_number, nil)

    patch admin_close_finance_period_path(2026, 6, finance_unit_id: finance_units(:main).id)

    assert_redirected_to admin_finance_period_path(2026, 6, finance_unit_id: finance_units(:main).id)
    assert_not FinancePeriod.find_by(finance_unit: finance_units(:main), year: 2026, month: 6)&.closed?
  end

  private

  def create_system_category(name)
    FinanceCategory.create!(
      code: name.parameterize,
      name: name,
      description: "Fixed expense category for this workflow test.",
      category_type: "expense",
      finance_unit: finance_units(:main),
      system_defined: true
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
