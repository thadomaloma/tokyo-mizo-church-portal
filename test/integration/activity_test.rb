require "test_helper"

class ActivityTest < ActionDispatch::IntegrationTest
  setup do
    @unit = finance_units(:main)
    @expense = finance_categories(:two)
    sign_in(users(:one))
  end

  test "adding, editing and deleting an entry all show, including what was deleted" do
    post admin_finance_transactions_path, params: { finance_transaction: entry_params(amount: 5_000, description: "Electric bill") }
    transaction = @unit.finance_transactions.find_by!(description: "Electric bill")
    patch admin_finance_transaction_path(transaction), params: { finance_transaction: entry_params(amount: 6_000, description: "Electric bill") }
    delete admin_finance_transaction_path(transaction)

    get admin_activities_path

    assert_response :success
    assert_select "[data-activity=added]", text: /User One\s+added an expense.*Electric bill.*¥5,000/m
    assert_select "[data-activity=edited]", text: /edited Electric bill.*Amount: ¥5,000 → ¥6,000/m
    assert_select "[data-activity=deleted]", text: /deleted an expense.*Electric bill.*¥6,000/m
    assert_includes page_text, "Today"

    get admin_activities_path(kind: "deleted")
    assert_select "[data-activity]", count: 1
  end

  test "closing and reopening a month and changing a budget show" do
    post admin_finance_period_closure_path(2026, 4, finance_unit_id: @unit.id)
    delete admin_finance_period_closure_path(2026, 4, finance_unit_id: @unit.id)
    patch admin_budget_path(2026), params: { finance_unit_id: @unit.id, amounts: { @expense.id => "120,000" } }
    patch admin_budget_path(2026), params: { finance_unit_id: @unit.id, amounts: { @expense.id => "90,000" } }

    get admin_activities_path

    assert_select "[data-activity=month]", text: /closed April 2026/
    assert_select "[data-activity=month]", text: /reopened April 2026/
    assert_select "[data-activity=budget]", text: /changed the 2026 budget.*Fixture Expense: set to ¥120,000/m
    assert_select "[data-activity=budget]", text: /Fixture Expense: ¥120,000 → ¥90,000/
  end

  test "many entries added together become one event" do
    12.times { |index| @unit.finance_transactions.create!(entry_params(amount: 100 + index, description: "import-#{index}").merge(recorded_by: users(:one))) }

    get admin_activities_path

    assert_select "[data-activity=added]", count: 1
    assert_select "[data-activity=added]", text: /System\s+added 12 entries.*expenses ¥1,266/m
  end

  test "people only see activity for their own finance units" do
    @unit.finance_transactions.create!(entry_params(amount: 700, description: "main-unit-entry").merge(recorded_by: users(:one)))
    FinanceUnitMembership.create!(user: users(:three), finance_unit: finance_units(:naupang), role: "treasurer")
    delete destroy_user_session_path
    sign_in(users(:three))

    get admin_activities_path

    assert_response :success
    assert_not_includes response.body, "main-unit-entry"
  end

  test "Activity and Categories are in the More menu" do
    get admin_root_path

    assert_select "nav[aria-label=Primary] a[href=?]", admin_activities_path, text: /Activity/
    assert_select "nav[aria-label=Primary] a[href=?]", admin_finance_categories_path, text: /Categories/
  end

  private

  def entry_params(amount:, description:)
    { finance_unit_id: @unit.id, transaction_type: "expense", finance_category_id: @expense.id, amount: amount,
      transaction_date: Date.current, payment_location: "cash", description: description }
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
