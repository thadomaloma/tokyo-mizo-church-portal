require "test_helper"
require "zip"

class FinanceReportExportTest < ActionDispatch::IntegrationTest
  test "finance export links bypass turbo for browser download compatibility" do
    sign_in_user

    get finance_admin_reports_path

    assert_response :success
    assert_select "a[data-turbo='false'][href*='.pdf']", text: /Export PDF/
    assert_select "a[data-turbo='false'][href*='.xlsx']", text: /Export Excel/
  end

  test "finance pdf export returns an attachment pdf response" do
    sign_in_user

    get finance_admin_reports_path(format: :pdf)

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
