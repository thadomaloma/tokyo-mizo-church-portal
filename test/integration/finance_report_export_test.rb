require "test_helper"
require "zip"

class FinanceReportExportTest < ActionDispatch::IntegrationTest
  test "finance export links bypass turbo for browser download compatibility" do
    sign_in_user

    get finance_admin_reports_path(summary_month: 4)

    assert_response :success
    assert_select "a[data-turbo='false'][href*='.pdf'][href*='summary_month=4']", text: /Export PDF/
    assert_select "a[data-turbo='false'][href*='.xlsx']", text: /Export Excel/
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

  test "finance report shows selected month only summary in the export block" do
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
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: income_category,
      recorded_by: users(:one),
      amount: 99_000,
      transaction_date: Date.new(2026, 1, 5),
      payment_location: "cash",
      description: "January income"
    )

    get finance_admin_reports_path(year: 2026, start_month: 1, end_month: 5)

    assert_response :success
    assert_includes response.body, "Monthly Summary"
    assert_includes response.body, "May 2026"
    assert_includes response.body, "¥10,000"
    assert_includes response.body, "¥3,000"
    assert_includes response.body, "¥7,000"
  end

  test "finance report monthly summary selector stays independent from the period filter" do
    sign_in_user
    income_category = FinanceCategory.create!(name: "April Tithe", category_type: "income")
    expense_category = FinanceCategory.create!(name: "April Expense", category_type: "expense")

    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: income_category,
      recorded_by: users(:one),
      amount: 8_000,
      transaction_date: Date.new(2026, 4, 5),
      payment_location: "cash",
      description: "April income"
    )
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: expense_category,
      recorded_by: users(:one),
      amount: 2_500,
      transaction_date: Date.new(2026, 4, 6),
      payment_location: "cash",
      description: "April expense"
    )

    get finance_admin_reports_path(year: 2026, start_month: 1, end_month: 5, summary_month: 4)

    assert_response :success
    assert_select "input[name='summary_month'][value='4']", visible: false
    assert_select "select[name='summary_month'] option[selected='selected'][value='4']", text: "April"
    assert_includes response.body, "January - May 2026, up to May"
    assert_includes response.body, "April 2026"
    assert_includes response.body, "¥8,000"
    assert_includes response.body, "¥2,500"
    assert_includes response.body, "¥5,500"
  end

  test "finance pdf export returns an attachment pdf response" do
    sign_in_user

    get finance_admin_reports_path(year: 2026, start_month: 1, end_month: 5, summary_month: 4, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
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

  test "finance excel export uses worksheet bars instead of a native chart object" do
    sign_in_user

    get finance_admin_reports_path(format: :xlsx)

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert response.body.start_with?("PK")

    Zip::File.open_buffer(response.body) do |zip_file|
      entry_names = zip_file.entries.map(&:name)

      assert_not entry_names.any? { |name| name.start_with?("xl/charts/") }
      assert_includes zip_file.read("xl/worksheets/sheet1.xml"), "Income vs Expense"
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
