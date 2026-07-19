require "test_helper"

class FinanceCategoryTest < ActiveSupport::TestCase
  test "filters categories by transaction type" do
    income = FinanceCategory.create!(name: "Tithe", category_type: "income")
    expense = FinanceCategory.create!(name: "Utilities", category_type: "expense")

    assert_includes FinanceCategory.for_transaction_type("income"), income
    assert_not_includes FinanceCategory.for_transaction_type("income"), expense
  end
end
