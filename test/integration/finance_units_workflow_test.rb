require "test_helper"
require "zip"

class FinanceUnitsWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @department_user = users(:three)
    @naupang = finance_units(:naupang)
    @thalai = finance_units(:thalai)
    @membership = FinanceUnitMembership.create!(
      finance_unit: @naupang,
      user: @department_user,
      role: "treasurer"
    )
    @naupang_income = FinanceCategory.create!(
      code: "naupang-test-income",
      name: "Naupang Offering",
      description: "Naupang fixed income category.",
      category_type: "income",
      finance_unit: @naupang,
      system_defined: true
    )
    @thalai_income = FinanceCategory.create!(
      code: "thalai-test-income",
      name: "Thalai Offering",
      description: "Thalai fixed income category.",
      category_type: "income",
      finance_unit: @thalai,
      system_defined: true
    )
  end

  test "department treasurer sees and manages only the assigned ledger" do
    sign_in(@department_user)

    get admin_finance_transactions_path(finance_unit_id: @naupang.id)

    assert_response :success
    assert_includes response.body, "Naupang Department"
    assert_select "a[href*='finance_unit_id=#{@naupang.id}']", text: /Income/

    assert_difference -> { @naupang.finance_transactions.count }, 1 do
      post admin_finance_transactions_path, params: {
        finance_transaction: {
          finance_unit_id: @naupang.id,
          transaction_type: "income",
          finance_category_id: @naupang_income.id,
          amount: 12_000,
          transaction_date: Date.current,
          payment_location: "cash",
          description: "Department-only marker"
        }
      }
    end

    transaction = @naupang.finance_transactions.order(:created_at).last
    assert_equal @department_user, transaction.recorded_by
    assert_redirected_to admin_finance_transactions_path(finance_unit_id: @naupang.id)
  end

  test "department treasurer cannot open or mutate an unassigned department" do
    sign_in(@department_user)

    get admin_finance_transactions_path(finance_unit_id: @thalai.id)
    assert_response :not_found

    assert_no_difference -> { FinanceTransaction.count } do
      post admin_finance_transactions_path, params: {
        finance_transaction: {
          finance_unit_id: @thalai.id,
          transaction_type: "income",
          finance_category_id: @thalai_income.id,
          amount: 5_000,
          transaction_date: Date.current,
          payment_location: "cash"
        }
      }
    end
    assert_response :not_found
  end

  test "department treasurer cannot view main church finance without an explicit assignment" do
    sign_in(@department_user)
    main = finance_units(:main)

    get admin_finance_transactions_path(finance_unit_id: main.id)
    assert_response :not_found

    get new_admin_finance_transaction_path(finance_unit_id: main.id, transaction_type: "income")
    assert_response :not_found
  end

  test "unit viewer can open expense receipts but cannot edit or delete records" do
    @membership.update!(role: "viewer")
    expense_category = FinanceCategory.create!(
      name: "Naupang Supplies",
      category_type: "expense",
      finance_unit: @naupang
    )
    expense = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      finance_unit: @naupang,
      recorded_by: users(:one),
      amount: 4_500,
      transaction_date: Date.current,
      payment_location: "cash"
    )
    sign_in(@department_user)

    get admin_finance_transactions_path(finance_unit_id: @naupang.id)

    assert_response :success
    assert_select "a[href='#{receipt_admin_finance_transaction_path(expense)}']", count: 1
    assert_select "a[href='#{edit_admin_finance_transaction_path(expense)}']", count: 0
    assert_select "form[action='#{admin_finance_transaction_path(expense)}']", count: 0

    get receipt_admin_finance_transaction_path(expense)

    assert_response :success
    assert_includes response.body, expense.expense_voucher_number
  end

  test "president can view a consolidated report across finance units" do
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: @naupang_income,
      finance_unit: @naupang,
      recorded_by: users(:one),
      amount: 7_000,
      transaction_date: Date.new(2026, 8, 1),
      payment_location: "cash",
      description: "NAUPANG-CONSOLIDATED-MARKER"
    )
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: @thalai_income,
      finance_unit: @thalai,
      recorded_by: users(:one),
      amount: 8_000,
      transaction_date: Date.new(2026, 8, 2),
      payment_location: "bank",
      description: "THALAI-CONSOLIDATED-MARKER"
    )
    sign_in(users(:one))

    get finance_admin_reports_path(
      finance_unit_id: "all",
      year: 2026,
      start_month: 8,
      end_month: 8
    )

    assert_response :success
    assert_includes response.body, "Consolidated Finance"
    assert_includes response.body, "NAUPANG-CONSOLIDATED-MARKER"
    assert_includes response.body, "THALAI-CONSOLIDATED-MARKER"
  end

  test "department excel export contains only the selected finance unit" do
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: @naupang_income,
      finance_unit: @naupang,
      recorded_by: users(:one),
      amount: 7_000,
      transaction_date: Date.new(2026, 8, 1),
      payment_location: "cash",
      description: "NAUPANG-EXPORT-MARKER"
    )
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: @thalai_income,
      finance_unit: @thalai,
      recorded_by: users(:one),
      amount: 8_000,
      transaction_date: Date.new(2026, 8, 2),
      payment_location: "bank",
      description: "THALAI-EXPORT-MARKER"
    )
    sign_in(@department_user)

    get finance_admin_reports_path(
      finance_unit_id: @naupang.id,
      year: 2026,
      start_month: 8,
      end_month: 8,
      format: :xlsx
    )

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "naupang-department_finance_report"

    Zip::File.open_buffer(response.body) do |zip_file|
      worksheet = zip_file.read("xl/worksheets/sheet1.xml")

      assert_includes worksheet, "Naupang Department"
      assert_includes worksheet, "NAUPANG-EXPORT-MARKER"
      assert_not_includes worksheet, "THALAI-EXPORT-MARKER"
    end
  end

  test "president clears an old assignment before moving a member to another role" do
    sign_in(users(:one))

    post admin_finance_unit_finance_unit_memberships_path(@thalai), params: {
      finance_unit_membership: {
        user_id: @department_user.id,
        role: "finance_secretary"
      }
    }

    membership = @thalai.finance_unit_memberships.find_by!(user: @department_user)
    assert_equal "finance_secretary", membership.role

    post admin_finance_unit_finance_unit_memberships_path(@thalai), params: {
      finance_unit_membership: {
        user_id: @department_user.id,
        role: "treasurer"
      }
    }

    assert_redirected_to admin_finance_units_path
    assert_equal "finance_secretary", membership.reload.role
    assert_match(/Finance secretary anga assign tawh/, flash[:alert])

    post admin_finance_unit_finance_unit_memberships_path(@thalai), params: {
      finance_unit_membership: { user_id: "", role: "finance_secretary" }
    }
    assert_not @thalai.finance_unit_memberships.exists?(user: @department_user)

    post admin_finance_unit_finance_unit_memberships_path(@thalai), params: {
      finance_unit_membership: { user_id: @department_user.id, role: "treasurer" }
    }
    assert_equal "treasurer", @thalai.finance_unit_memberships.find_by!(user: @department_user).role
  end

  test "president can open finance unit administration" do
    sign_in(users(:one))

    get admin_finance_units_path

    assert_response :success
    assert_select "h1", text: "Finance Access"
    assert_includes response.body, "Naupang Department"
    assert_includes response.body, "Building Sum"
    assert_includes response.body, "Mission Sum"
    assert_no_match(/Add Finance Unit/, response.body)
    select_ids = css_select("select[id^='finance-unit-']").map { |select| select["id"] }
    assert_equal select_ids.uniq, select_ids
    assert_select "label[for='finance-unit-#{@naupang.id}-treasurer']", text: "Treasurer"
    assert_select "section[data-finance-unit-id='#{@naupang.id}']" do
      assert_select "select[id='finance-unit-#{@naupang.id}-treasurer'] option[value='#{@department_user.id}']", text: /#{Regexp.escape(@department_user.name)}/
      assert_select "select[id='finance-unit-#{@naupang.id}-treasurer'] option[value='#{@department_user.id}']", text: /#{Regexp.escape(@department_user.email)}/
      assert_select "select[id='finance-unit-#{@naupang.id}-viewer'] option[value='#{@department_user.id}']", count: 0
    end
  end

  test "adding a manager as a viewer does not silently remove manager access" do
    sign_in(users(:one))

    post admin_finance_unit_finance_unit_memberships_path(@naupang), params: {
      finance_unit_membership: { user_id: @department_user.id, role: "viewer" }
    }

    assert_redirected_to admin_finance_units_path
    assert_equal "treasurer", @membership.reload.role
    assert_match(/Treasurer anga assign tawh/, flash[:alert])
  end

  test "an unassigned member cannot open finance ledger or export reports" do
    unassigned = User.create!(
      name: "No Finance Access",
      email: "no-finance-access@example.com",
      password: "secure-password",
      role: :treasurer
    )
    sign_in(unassigned, password: "secure-password")

    get admin_finance_transactions_path
    assert_redirected_to admin_root_path

    get finance_admin_reports_path(format: :xlsx)
    assert_redirected_to admin_root_path
  end

  private

  def sign_in(user, password: "password")
    post user_session_path, params: {
      user: { email: user.email, password: password }
    }
  end
end
