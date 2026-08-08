require "test_helper"

class FinanceCategoryTest < ActiveSupport::TestCase
  test "filters categories by transaction type" do
    income = FinanceCategory.create!(name: "Tithe", category_type: "income")
    expense = FinanceCategory.create!(name: "Utilities", category_type: "expense")

    assert_includes FinanceCategory.for_transaction_type("income"), income
    assert_not_includes FinanceCategory.for_transaction_type("income"), expense
  end

  test "does not allow a used category to change transaction type" do
    category = FinanceCategory.create!(name: "Offering", category_type: "income")
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      recorded_by: users(:one),
      amount: 5_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )

    category.category_type = "expense"

    assert_not category.valid?
    assert_includes category.errors[:category_type], "cannot be changed after finance entries use this category"
  end
end
