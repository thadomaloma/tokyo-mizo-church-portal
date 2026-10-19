require "test_helper"

class BankAccountNameTest < ActionDispatch::IntegrationTest
  setup do
    @unit = finance_units(:main)
    sign_in_as users(:one)
  end

  test "units say Bank until a bank name is set" do
    assert_equal "Bank", @unit.account_label("bank")
    assert_equal "Cash", @unit.account_label("cash")

    @unit.update!(bank_account_name: "  Yucho   Bank ")
    assert_equal "Yucho Bank", @unit.account_label("bank")
    assert_equal [ [ "Cash", "cash" ], [ "Yucho Bank", "bank" ] ], @unit.account_options

    @unit.update!(bank_account_name: " ")
    assert_nil @unit.bank_account_name
  end

  test "an admin names the bank account and every screen uses it" do
    patch admin_finance_unit_path(@unit), params: { finance_unit: { name: @unit.name, bank_account_name: "Yucho Bank" } }
    assert_redirected_to admin_finance_units_path

    get admin_root_path(finance_unit_id: @unit.id)
    assert_select "[data-balance-card]", text: /Yucho Bank/

    get admin_accounts_path(finance_unit_id: @unit.id)
    assert_select "[data-account=bank] .card-title", text: "Yucho Bank"
    assert_select "[data-account=bank] a", text: "Rename"

    get new_admin_finance_transaction_path(finance_unit_id: @unit.id, transaction_type: "expense")
    assert_select "select[name='finance_transaction[payment_location]'] option[value=bank]", text: "Yucho Bank"

    get new_admin_offering_path(finance_unit_id: @unit.id)
    assert_select "option[value=bank]", text: "Yucho Bank"

    get admin_finance_period_path(Date.current.year, Date.current.month, finance_unit_id: @unit.id)
    assert_match "Yucho Bank", page_text
  end

  test "a bank expense voucher says which bank paid" do
    @unit.update!(bank_account_name: "Yucho Bank")
    expense = FinanceTransaction.create!(
      finance_unit: @unit, transaction_type: "expense", payment_location: "bank", amount: 5_000,
      transaction_date: Date.current, recorded_by: users(:one),
      finance_category: @unit.finance_categories.create!(name: "Bank test", category_type: "expense")
    )

    get admin_finance_transaction_voucher_path(expense)

    assert_select "[data-voucher] dd", text: "Yucho Bank"
  end

  test "the report export uses the bank name" do
    @unit.update!(bank_account_name: "Yucho Bank")

    get admin_finance_report_path(finance_unit_id: @unit.id, format: :xlsx)

    assert_response :success
    xml = +""
    Zip::File.open_buffer(response.body) { |zip| zip.glob("xl/**/*.xml").each { |entry| xml << entry.get_input_stream.read } }
    assert_match "Yucho Bank", xml
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
