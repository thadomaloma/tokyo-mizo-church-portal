require "test_helper"

class MonthlyBillsTest < ActionDispatch::IntegrationTest
  setup do
    @unit = finance_units(:main)
    FinanceCategory.install_system_catalog_for!(@unit)
    @rent = category("rent")
    @utilities = category("utilities")
    @food = category("food_refreshments")
    # August–October: rent and the electric bill monthly, food every week,
    # and a one-off purchase.
    [ 8, 9, 10 ].each do |month|
      expense(@rent, 165_000, Date.new(2026, month, 1), "Inluah man", location: "bank")
      expense(@utilities, 15_000 + month, Date.new(2026, month, 20), "Electric bill")
      [ 7, 14, 21 ].each { |day| expense(@food, 5_000, Date.new(2026, month, day), "Ei leh in") }
    end
    expense(category("equipment_supplies"), 62_230, Date.new(2026, 9, 21), "Mic lei na")
    [ 9, 10 ].each { |month| expense(@utilities, 2_400, Date.new(2026, month, 25), "Water bill") }
    post user_session_path, params: { user: { email: users(:one).email, password: "password" } }
  end

  test "finds the monthly bills with last time's amount and account" do
    get new_admin_monthly_bill_path(finance_unit_id: @unit.id, month: "2026-11")

    assert_response :success
    assert_select "[data-monthly-bills] li", count: 3
    assert_select "[data-monthly-bills] li", text: /Water bill.*Not every month/m
    assert_select "input[value='2400']", count: 0
    assert_select "[data-monthly-bills] li", text: /Inluah man.*Last: ¥165,000 on 1 Oct/m
    assert_select "[data-monthly-bills] li", text: /Electric bill.*Last: ¥15,010 on 20 Oct/m
    assert_select "input[value='15010']"
    assert_select "select option[selected][value=bank]"
    assert_no_match "Ei leh in", response.body
    assert_no_match "Mic lei na", response.body
  end

  test "saves the bills as separate expenses with vouchers" do
    get new_admin_monthly_bill_path(finance_unit_id: @unit.id, month: "2026-11")
    rent_key, electric_key = bill_key("Inluah man"), bill_key("Electric bill")

    assert_difference -> { @unit.finance_transactions.expense.where(transaction_date: Date.new(2026, 11).all_month).count }, 2 do
      post admin_monthly_bills_path(finance_unit_id: @unit.id, month: "2026-11"), params: { monthly_bills: {
        transaction_date: "2026-11-05",
        entries: { rent_key => { amount: "165,000", payment_location: "bank" }, electric_key => { amount: "16550", payment_location: "cash" } }
      } }
    end

    assert_redirected_to admin_finance_transactions_path(finance_unit_id: @unit.id)
    assert_equal "2 bills for November 2026 saved (¥181,550).", flash[:notice]
    electric = @unit.finance_transactions.find_by!(description: "Electric bill", transaction_date: Date.new(2026, 11, 5))
    assert_equal [ 16_550, "cash", @utilities ], [ electric.amount, electric.payment_location, electric.finance_category ]
    assert electric.expense_voucher_number

    get new_admin_monthly_bill_path(finance_unit_id: @unit.id, month: "2026-11")
    assert_select ".chip", text: "Already added on 5 Nov", count: 2
    assert_select "[data-monthly-bills] input[type=number][value]", count: 0
  end

  test "refuses a date outside the month, bad amounts and closed months" do
    get new_admin_monthly_bill_path(finance_unit_id: @unit.id, month: "2026-11")
    key = bill_key("Electric bill")
    submit = ->(date, amount) { post admin_monthly_bills_path(finance_unit_id: @unit.id, month: "2026-11"), params: { monthly_bills: { transaction_date: date, entries: { key => { amount: amount } } } } }

    assert_no_difference -> { FinanceTransaction.count } do
      submit.call("2026-12-01", "100")
      assert_includes page_text, "Transaction date must be in November 2026"
      submit.call("2026-11-05", "12.5")
      assert_includes page_text, "Amounts must be whole numbers"
      submit.call("2026-11-05", "")
      assert_includes page_text, "Enter an amount for at least one bill"
      FinancePeriod.create!(finance_unit: @unit, year: 2026, month: 11, status: :closed, closed_at: Time.current, closed_by: users(:one))
      submit.call("2026-11-05", "100")
      assert_includes page_text, "November 2026 is closed"
    end
  end

  private

  # The form key of the bill whose row shows `name`.
  def bill_key(name)
    row = css_select("[data-monthly-bills] li").find { |li| li.text.include?(name) }
    row.at_css("input[type=number]")["name"][/entries\]\[(\w+)\]/, 1]
  end

  def category(code)
    @unit.finance_categories.find_by!(code: code, category_type: "expense")
  end

  def expense(category, amount, date, note, location: "cash")
    @unit.finance_transactions.create!(transaction_type: "expense", finance_category: category, amount: amount, transaction_date: date,
                                       payment_location: location, description: note, recorded_by: users(:one))
  end
end
