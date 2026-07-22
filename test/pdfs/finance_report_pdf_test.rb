require "test_helper"

class FinanceReportPdfTest < ActiveSupport::TestCase
  test "renders finance report with compact monthly summary spacing" do
    tithe_category = FinanceCategory.new(name: "Sawm Pakhat", category_type: "income")
    offering_category = FinanceCategory.new(name: "Thawh Hlawm", category_type: "income")
    expense_category = FinanceCategory.new(name: "Utilities", category_type: "expense")

    transactions = [
      finance_transaction(tithe_category, "income", 12_000, Date.new(2026, 6, 5)),
      finance_transaction(offering_category, "income", 8_000, Date.new(2026, 6, 6)),
      finance_transaction(expense_category, "expense", 3_000, Date.new(2026, 6, 7))
    ]

    pdf = FinanceReportPdf.new(
      transactions: transactions,
      income: 20_000,
      expense: 3_000,
      balance: 17_000,
      period_label: "June 2026",
      period_year: 2026,
      start_month: 6,
      end_month: 6
    ).render

    assert pdf.start_with?("%PDF")
  end

  test "renders January to July finance report with unicode transaction text" do
    unicode_category = FinanceCategory.new(name: "献金 Sawm a Pakhat", category_type: "income")
    expense_category = FinanceCategory.new(name: "礼拝 Hall Rent", category_type: "expense")

    transactions = [
      finance_transaction(unicode_category, "income", 12_000, Date.new(2026, 1, 5), description: "東京ミゾ教会 tithe â"),
      finance_transaction(unicode_category, "income", 8_000, Date.new(2026, 7, 6), description: "July offering - 献金"),
      finance_transaction(expense_category, "expense", 3_000, Date.new(2026, 7, 7), description: "礼拝 hall payment")
    ]

    pdf = FinanceReportPdf.new(
      transactions: transactions,
      income: 20_000,
      expense: 3_000,
      balance: 17_000,
      period_label: "January - July 2026",
      period_year: 2026,
      start_month: 1,
      end_month: 7
    ).render

    assert pdf.start_with?("%PDF")
  end

  private

  def finance_transaction(category, transaction_type, amount, transaction_date, description: category.name)
    FinanceTransaction.new(
      transaction_type: transaction_type,
      finance_category: category,
      amount: amount,
      transaction_date: transaction_date,
      payment_location: "cash",
      description: description,
      created_at: Time.zone.local(2026, 6, transaction_date.day, 10)
    )
  end
end
