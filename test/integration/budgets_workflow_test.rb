require "test_helper"

class BudgetsWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @unit = finance_units(:main)
    @expense_category = finance_categories(:two)
    @year = Date.current.year
  end

  test "a manager creates a yearly budget and sees spending against it" do
    sign_in(users(:one))
    spend(30_000)

    get admin_budget_path(@year, finance_unit_id: @unit.id)
    assert_response :success
    assert_includes page_text, "No budget for #{@year} yet"

    patch admin_budget_path(@year), params: { finance_unit_id: @unit.id, amounts: { @expense_category.id => "120,000" } }
    assert_redirected_to admin_budget_path(@year, finance_unit_id: @unit.id)

    budget = FinanceBudget.for(@unit, @year)
    assert_equal 120_000, budget.planned_total

    spent = BudgetProgress.new(@unit, @year).spent_total
    assert_operator spent, :>=, 30_000

    follow_redirect!
    assert_select "[data-budget-summary]", text: /¥#{spent.to_fs(:delimited)}.*¥120,000/m
    assert_select "li", text: /Fixture Expense/
  end

  test "clearing an amount removes that line" do
    sign_in(users(:one))
    budget = FinanceBudget.create!(finance_unit: @unit, year: @year)
    budget.lines.create!(finance_category: @expense_category, amount: 5_000)

    patch admin_budget_path(@year), params: { finance_unit_id: @unit.id, amounts: { @expense_category.id => "" } }

    assert_equal 0, budget.reload.lines.count
  end

  test "invalid amounts are rejected without changing the budget" do
    sign_in(users(:one))

    patch admin_budget_path(@year), params: { finance_unit_id: @unit.id, amounts: { @expense_category.id => "abc" } }

    assert_response :unprocessable_entity
    assert_nil FinanceBudget.for(@unit, @year)
  end

  test "income categories cannot be budgeted" do
    budget = FinanceBudget.create!(finance_unit: @unit, year: @year)
    line = budget.lines.new(finance_category: finance_categories(:one), amount: 1_000)

    assert_not line.valid?
  end

  test "budget progress reports over-budget and unplanned spending" do
    budget = FinanceBudget.create!(finance_unit: @unit, year: @year)
    budget.lines.create!(finance_category: @expense_category, amount: 10_000)
    spend(12_000)

    progress = BudgetProgress.new(@unit, @year)

    assert progress.lines.first.over?
    assert_operator progress.percent_used, :>=, 120
    assert_equal :over, progress.status
    assert_equal 0, progress.unplanned_spending
  end

  test "viewers without manager rights cannot edit the budget" do
    viewer = User.create!(name: "Viewer", email: "viewer@example.com", password: "secure-password", role: :finance_secretary)
    FinanceUnitMembership.create!(finance_unit: @unit, user: viewer, role: "viewer")
    post user_session_path, params: { user: { email: viewer.email, password: "secure-password" } }

    get admin_budget_path(@year, finance_unit_id: @unit.id)
    assert_response :success

    get edit_admin_budget_path(@year, finance_unit_id: @unit.id)
    assert_redirected_to admin_budget_path(@year, finance_unit_id: @unit.id)
  end

  test "the dashboard shows the budget card" do
    sign_in(users(:one))
    budget = FinanceBudget.create!(finance_unit: @unit, year: @year)
    budget.lines.create!(finance_category: @expense_category, amount: 10_000)
    spend(5_000)

    get admin_root_path

    assert_select "[data-budget-card]", text: /#{BudgetProgress.new(@unit, @year).percent_used}%/
  end

  private

  def spend(amount)
    @unit.finance_transactions.create!(
      transaction_type: "expense", amount: amount, transaction_date: Date.current,
      payment_location: "cash", finance_category: @expense_category, recorded_by: users(:one)
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
