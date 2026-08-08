require "application_system_test_case"
require "base64"
require "fileutils"

class ExpenseReceiptPrintTest < ApplicationSystemTestCase
  test "prints a non-empty A5 expense receipt" do
    category = FinanceCategory.create!(name: "Print Test", category_type: "expense")
    transaction = FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      recorded_by: users(:one),
      amount: 12_500,
      transaction_date: Date.new(2026, 8, 8),
      payment_location: "bank",
      description: "Receipt print test"
    )

    visit root_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign In"

    assert_current_path authenticated_root_path
    assert_text "Welcome back, #{users(:one).name}"
    visit receipt_admin_finance_transaction_path(transaction)
    assert_text "Tokyo Mizo Church"
    assert_text transaction.expense_voucher_number

    result = page.driver.browser.execute_cdp(
      "Page.printToPDF",
      printBackground: true,
      preferCSSPageSize: true
    )
    pdf_data = Base64.decode64(result.fetch("data"))
    if ENV["KEEP_PRINT_PDF"] == "1"
      output_path = Rails.root.join("tmp", "pdfs", "expense-receipt-print.pdf")
      FileUtils.mkdir_p(output_path.dirname)
      File.binwrite(output_path, pdf_data)
    end

    assert pdf_data.start_with?("%PDF")
    assert_operator pdf_data.bytesize, :>, 10_000
  end
end
