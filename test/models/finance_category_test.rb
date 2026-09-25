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

  test "does not allow a used category to move between finance units" do
    category = FinanceCategory.create!(
      name: "Department Offering",
      category_type: "income",
      finance_unit: finance_units(:naupang)
    )
    FinanceTransaction.create!(
      transaction_type: "income",
      finance_category: category,
      finance_unit: category.finance_unit,
      recorded_by: users(:one),
      amount: 5_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )

    category.finance_unit = finance_units(:thalai)

    assert_not category.valid?
    assert_includes category.errors[:finance_unit], "cannot be changed after finance entries use this category"
  end

  test "rejects a duplicate category name case-insensitively within the same unit and type" do
    FinanceCategory.create!(name: "Fundraising", category_type: "income")
    duplicate = FinanceCategory.new(name: "FUNDRAISING", category_type: "income")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows the same name across different transaction types" do
    FinanceCategory.create!(name: "Transport", category_type: "income")
    expense_version = FinanceCategory.new(name: "Transport", category_type: "expense")

    assert expense_version.valid?
  end

  test "allows the same name across different finance units" do
    FinanceCategory.create!(name: "Offering", category_type: "income", finance_unit: finance_units(:naupang))
    other_unit_version = FinanceCategory.new(name: "Offering", category_type: "income", finance_unit: finance_units(:thalai))

    assert other_unit_version.valid?
  end

  test "system categories cannot be edited or deleted" do
    category = FinanceCategory.create!(
      code: "protected-test",
      name: "Protected Category",
      description: "System controlled category.",
      category_type: "income",
      finance_unit: finance_units(:main),
      system_defined: true
    )

    category.name = "Changed Name"
    assert_not category.save
    assert_includes category.errors[:base], "System finance categories cannot be edited"

    assert_not category.destroy
    assert_includes category.errors[:base], "System finance categories cannot be deleted"
    assert category.reload.persisted?
  end

  test "catalog differs by finance unit type" do
    church_codes = FinanceCategory.system_catalog_for(finance_units(:main)).pluck(:code)
    fund_codes = FinanceCategory.system_catalog_for(finance_units(:building)).pluck(:code)

    assert_includes church_codes, "tithe"
    assert_includes church_codes, "thanksgiving_offering"
    assert_includes church_codes, "children_ministry"
    assert_not_includes fund_codes, "tithe"
    assert_includes fund_codes, "fund_project"
  end

  test "catalog names put English first and Mizo in parentheses" do
    tithe = FinanceCategory::SYSTEM_CATALOG.find { |entry| entry.fetch(:code) == "tithe" }

    assert_equal "Tithe (Sawm a Pakhat)", tithe.fetch(:name)
  end

  test "option label does not include the internal description" do
    category = finance_categories(:two)

    assert_equal category.name, category.option_label
    assert_not_includes category.option_label, category.description
  end
end
