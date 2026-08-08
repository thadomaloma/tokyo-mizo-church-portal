require "test_helper"
require "zip"

class FinanceReportExportTest < ActionDispatch::IntegrationTest
  test "finance export links bypass turbo for browser download compatibility" do
    sign_in_user

    get finance_admin_reports_path(year: 2026, start_month: 2, end_month: 4, ledger_type: "expense")

    assert_response :success
    assert_select "a[data-turbo='false'][href*='.pdf'][href*='ledger_type=expense'][href*='start_month=2'][href*='end_month=4']", text: /Export PDF/
    assert_select "a[data-turbo='false'][href*='.xlsx'][href*='ledger_type=expense'][href*='start_month=2'][href*='end_month=4']", text: /Export Excel/
  end

  test "finance report shows selected period as an up-to month summary" do
    sign_in_user

    get finance_admin_reports_path(year: 2026, start_month: 1, end_month: 5)

    assert_response :success
    assert_includes response.body, "January - May 2026, up to May"
    assert_select "p", text: "Income"
    assert_select "p", text: "Expense"
    assert_select "p", text: "Balance"
  end

  test "finance report filters the ledger by type while preserving the selected period" do
    sign_in_user
    income_category = FinanceCategory.create!(name: "May Tithe", category_type: "income")
    expense_category = FinanceCategory.create!(name: "May Expense", category_type: "expense")

    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: income_category,
      recorded_by: users(:one),
      amount: 10_000,
      transaction_date: Date.new(2026, 5, 5),
      payment_location: "cash",
      description: "May income"
    )
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 3_000,
      transaction_date: Date.new(2026, 5, 6),
      payment_location: "cash",
      description: "May expense"
    )
    get finance_admin_reports_path(year: 2026, start_month: 4, end_month: 5, ledger_type: "income")

    assert_response :success
    assert_includes response.body, "Ledger View"
    assert_includes response.body, "April - May 2026 Income Transactions"
    assert_includes response.body, "May income"
    assert_not_includes response.body, "May expense"
    assert_includes response.body, "¥10,000"
    assert_select "input[name='ledger_type'][value='income']", visible: false
    assert_select "a[aria-current='page']", text: "Income"
  end

  test "ledger type links retain year and month range" do
    sign_in_user
    get finance_admin_reports_path(year: 2025, start_month: 3, end_month: 8, ledger_type: "expense")

    assert_response :success
    assert_select "a[href*='year=2025'][href*='start_month=3'][href*='end_month=8'][href*='ledger_type=all']", text: "All"
    assert_select "a[href*='year=2025'][href*='start_month=3'][href*='end_month=8'][href*='ledger_type=income']", text: "Income"
    assert_select "a[href*='year=2025'][href*='start_month=3'][href*='end_month=8'][href*='ledger_type=expense']", text: "Expense"
  end

  test "finance pdf export returns an attachment pdf response" do
    sign_in_user

    get finance_admin_reports_path(year: 2026, start_month: 1, end_month: 5, ledger_type: "income", format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "finance_report_income_"
    assert response.body.start_with?("%PDF")
  end

  test "finance pdf export supports January to July period with unicode transaction text" do
    sign_in_user
    category = FinanceCategory.create!(name: "献金 Sawm a Pakhat", category_type: "income")

    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      recorded_by: users(:one),
      amount: 12_000,
      transaction_date: Date.new(2026, 7, 5),
      payment_location: "cash",
      description: "東京ミゾ教会 tithe â"
    )

    get finance_admin_reports_path(
      year: 2026,
      start_month: 1,
      end_month: 7,
      format: :pdf
    )

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "finance excel export uses a compact comparison section instead of a native chart object" do
    sign_in_user

    get finance_admin_reports_path(format: :xlsx)

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert response.body.start_with?("PK")

    Zip::File.open_buffer(response.body) do |zip_file|
      entry_names = zip_file.entries.map(&:name)

      assert_not entry_names.any? { |name| name.start_with?("xl/charts/") }
      assert_includes zip_file.read("xl/worksheets/sheet1.xml"), "INCOME VS EXPENSE"
    end
  end

  test "finance excel export contains only the selected ledger type" do
    sign_in_user
    income_category = FinanceCategory.create!(name: "Export Income", category_type: "income")
    expense_category = FinanceCategory.create!(name: "Export Expense", category_type: "expense")

    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: income_category,
      recorded_by: users(:one),
      amount: 15_000,
      transaction_date: Date.new(2026, 6, 5),
      payment_location: "bank",
      description: "INCOME-ONLY-EXPORT-MARKER"
    )
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 4_000,
      transaction_date: Date.new(2026, 6, 6),
      payment_location: "cash",
      description: "EXPENSE-ONLY-EXPORT-MARKER"
    )

    get finance_admin_reports_path(
      year: 2026,
      start_month: 6,
      end_month: 6,
      ledger_type: "expense",
      format: :xlsx
    )

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "finance_report_expense_"

    Zip::File.open_buffer(response.body) do |zip_file|
      worksheet = zip_file.read("xl/worksheets/sheet1.xml")

      assert_includes worksheet, "EXPENSE-ONLY-EXPORT-MARKER"
      assert_not_includes worksheet, "INCOME-ONLY-EXPORT-MARKER"
    end
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
