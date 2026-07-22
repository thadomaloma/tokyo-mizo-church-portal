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
