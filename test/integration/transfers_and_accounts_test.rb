require "test_helper"

class TransfersAndAccountsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @unit = finance_units(:main)
    record("income", 50_000, "cash", category: finance_categories(:one))
    record("expense", 8_000, "bank", category: finance_categories(:two))
    sign_in(@user)
  end

  test "a transfer moves money between accounts without changing totals" do
    assert_difference -> { @unit.finance_transactions.transfers.count }, 1 do
      post admin_finance_transactions_path, params: {
        finance_transaction: {
          finance_unit_id: @unit.id,
          transaction_type: "transfer",
          amount: 30_000,
          transaction_date: Date.current,
          payment_location: "cash",
          transfer_to_location: "bank",
          description: "Deposit"
        }
      }
    end

    transfer = @unit.finance_transactions.transfers.last
    assert_nil transfer.finance_category
    assert_nil transfer.voucher_number

    summary = FinanceSummary.new(@unit)
    assert_equal 20_000, summary.cash_balance
    assert_equal 22_000, summary.bank_balance
    assert_equal 42_000, summary.current_balance
    assert_equal 50_000, summary.month_income
    assert_equal 8_000, summary.month_expense
  end

  test "a transfer must go to a different account" do
    transfer = @unit.finance_transactions.new(
      transaction_type: "transfer", amount: 1_000, transaction_date: Date.current,
      payment_location: "cash", transfer_to_location: "cash", recorded_by: @user
    )

    assert_not transfer.valid?
    assert_includes transfer.errors[:transfer_to_location], "must be a different account"
  end

  test "income and expense still require a category and cannot carry a transfer target" do
    entry = @unit.finance_transactions.new(
      transaction_type: "expense", amount: 1_000, transaction_date: Date.current,
      payment_location: "cash", transfer_to_location: "bank", recorded_by: @user
    )

    assert_not entry.valid?
    assert entry.errors[:finance_category].any?
    assert entry.errors[:transfer_to_location].any?
  end

  test "the transfer form offers from and to accounts instead of a category" do
    get new_admin_finance_transaction_path(finance_unit_id: @unit.id, transaction_type: "transfer")

    assert_response :success
    assert_select "select[name='finance_transaction[transfer_to_location]']"
    assert_select "select[name='finance_transaction[finance_category_id]']", count: 0
    assert_select "a[aria-current='page']", text: /Transfer/
  end

  test "accounts page shows each account balance and its transfers" do
    record("transfer", 30_000, "cash", to: "bank", description: "Bank deposit")

    get admin_accounts_path(finance_unit_id: @unit.id)

    assert_response :success
    assert_select "[data-account='cash']", text: /¥20,000/
    assert_select "[data-account='bank']", text: /¥22,000/
    assert_select "[data-account='bank'] li", text: /Bank deposit.*\+¥30,000/m
    assert_select "[data-account='cash'] li", text: /Bank deposit.*−¥30,000/m
  end

  test "filtering the ledger by account includes transfers into it" do
    record("transfer", 30_000, "cash", to: "bank", description: "Bank deposit")

    get admin_finance_transactions_path(finance_unit_id: @unit.id, payment_location: "bank")

    assert_response :success
    assert_match "Bank deposit", response.body
  end

  test "finance reports leave transfers out of the ledger and totals" do
    record("transfer", 30_000, "cash", to: "bank", description: "Bank deposit")

    get finance_admin_reports_path(finance_unit_id: @unit.id)

    assert_response :success
    assert_no_match "Bank deposit", response.body
    assert_select "[data-spending-by-category]", text: /Fixture Expense/
  end

  private

  def record(type, amount, location, category: nil, to: nil, description: nil)
    @unit.finance_transactions.create!(
      transaction_type: type, amount: amount, transaction_date: Date.current,
      payment_location: location, transfer_to_location: to, finance_category: category,
      description: description, recorded_by: @user
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
