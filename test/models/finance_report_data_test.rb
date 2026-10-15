require "test_helper"

class FinanceReportDataTest < ActiveSupport::TestCase
  test "monthly tithe and offering totals match common category name variants" do
    tithe_category = FinanceCategory.create!(name: "Sawm Pakhat", category_type: "income")
    offering_category = FinanceCategory.create!(name: "Thawh Hlawm", category_type: "income")
    other_category = FinanceCategory.create!(name: "Donation", category_type: "income")

    tithe = finance_transaction(tithe_category, amount: 12_000)
    offering = finance_transaction(offering_category, amount: 8_000)
    donation = finance_transaction(other_category, amount: 5_000)

    report_data = FinanceReportData.new(
      transactions: [ tithe, offering, donation ],
      income: 25_000,
      expense: 0,
      balance: 25_000,
      period_year: 2026,
      start_month: 6,
      end_month: 6
    )

    assert_equal [ [ "Jun 2026", 12_000, 8_000 ] ],
                 report_data.monthly_tithe_offering_rows

    assert_equal "Tokyo", Rails.application.config.time_zone
  end


  test "coded categories decide giving: special and thanksgiving offerings are not counted as offering" do
    unit = finance_units(:main)
    FinanceCategory.install_system_catalog_for!(unit)
    tithe = unit.finance_categories.find_by!(code: "tithe")
    offering = unit.finance_categories.find_by!(code: "offering")
    special = unit.finance_categories.find_by!(code: "special_offering")
    thanksgiving = unit.finance_categories.find_by!(code: "thanksgiving_offering")

    transactions = [ [ tithe, 10_000 ], [ offering, 3_000 ], [ special, 7_000 ], [ thanksgiving, 2_000 ] ].map do |category, amount|
      finance_transaction(category, amount: amount)
    end
    report_data = FinanceReportData.new(transactions: transactions, income: 22_000, expense: 0, balance: 22_000,
                                        period_year: 2026, start_month: 6, end_month: 6)

    assert_equal [ [ "Jun 2026", 10_000, 3_000 ] ], report_data.monthly_tithe_offering_rows
  end

  private

  def finance_transaction(category, amount:)
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      recorded_by: users(:one),
      amount: amount,
      transaction_date: Date.new(2026, 6, 5),
      payment_location: "cash"
    )
  end
end
