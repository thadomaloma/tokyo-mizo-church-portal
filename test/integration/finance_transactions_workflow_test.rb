require "test_helper"

class FinanceTransactionsWorkflowTest < ActionDispatch::IntegrationTest
  test "finance page excludes the retired monthly summary and keeps the full ledger" do
    sign_in(users(:one))
    category = finance_categories(:two)
    first = create_transaction(category: category, description: "monthly summary removal one")
    second = create_transaction(category: category, description: "monthly summary removal two")

    get admin_finance_transactions_path(finance_unit_id: finance_units(:main).id)

    assert_response :success
    assert_select "section", text: /Monthly Summary/, count: 0
    assert_match first.description, response.body
    assert_match second.description, response.body
    assert_match(/Cash Balance/, response.body)
    assert_match(/Bank Balance/, response.body)
  end

  test "new entry form shows concise fixed categories without an add option" do
    sign_in(users(:one))

    get new_admin_finance_transaction_path(
      finance_unit_id: finance_units(:main).id,
      transaction_type: "expense"
    )

    assert_response :success
    assert_select "select[name='finance_transaction[finance_category_id]'] option", text: /Fixture Expense/
    assert_no_match(/Fixed expense category for tests/, response.body)
    assert_no_match(/Add New Category/, response.body)
    assert_match(/Description \/ Note/, response.body)
  end

  test "category guide is read only and does not show descriptions" do
    sign_in(users(:one))

    get admin_finance_categories_path(finance_unit_id: finance_units(:main).id)

    assert_response :success
    assert_select "h1", text: "Category Guide"
    assert_match(/Fixture Income/, response.body)
    assert_match(/Fixture Expense/, response.body)
    assert_no_match(/Fixed income category for tests/, response.body)
    assert_no_match(/Fixed expense category for tests/, response.body)
    assert_no_match(/Add Category|Edit|Delete/, response.body)
  end

  test "creates an entry with an assigned fixed category" do
    sign_in(users(:one))
    category = finance_categories(:two)

    assert_no_difference "FinanceCategory.count" do
      assert_difference "FinanceTransaction.count", 1 do
        post admin_finance_transactions_path, params: {
          finance_unit_id: finance_units(:main).id,
          finance_transaction: {
            transaction_type: "expense",
            finance_category_id: category.id,
            amount: 1_200,
            transaction_date: Date.current,
            payment_location: "cash"
          }
        }
      end
    end

    transaction = FinanceTransaction.order(:created_at).last
    assert_equal category, transaction.finance_category
    assert_redirected_to admin_finance_transactions_path(finance_unit_id: finance_units(:main).id)
  end

  test "rejects a legacy or arbitrary category id" do
    sign_in(users(:one))
    legacy_category = FinanceCategory.create!(
      name: "Freestyle Description",
      category_type: "expense",
      finance_unit: finance_units(:main)
    )

    assert_no_difference "FinanceTransaction.count" do
      post admin_finance_transactions_path, params: {
        finance_unit_id: finance_units(:main).id,
        finance_transaction: {
          transaction_type: "expense",
          finance_category_id: legacy_category.id,
          amount: 1_200,
          transaction_date: Date.current,
          payment_location: "cash"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "ledger search matches description and category name" do
    sign_in(users(:one))
    category = FinanceCategory.create!(name: "Distinctive Category", category_type: "expense", finance_unit: finance_units(:main))
    matching = create_transaction(category: category, description: "Distinctive keyword ZEBRA")
    other_category = FinanceCategory.create!(name: "Other", category_type: "expense", finance_unit: finance_units(:main))
    non_matching = create_transaction(category: other_category, description: "unrelated entry")

    get admin_finance_transactions_path(finance_unit_id: finance_units(:main).id, q: "ZEBRA")

    assert_response :success
    assert_match matching.description, response.body
    assert_no_match(/unrelated entry/, response.body)
  end

  test "ledger category filter narrows results to the selected category" do
    sign_in(users(:one))
    category_a = FinanceCategory.create!(name: "Filter Category A", category_type: "expense", finance_unit: finance_units(:main))
    category_b = FinanceCategory.create!(name: "Filter Category B", category_type: "expense", finance_unit: finance_units(:main))
    in_category = create_transaction(category: category_a, description: "in category a")
    create_transaction(category: category_b, description: "in category b")

    get admin_finance_transactions_path(finance_unit_id: finance_units(:main).id, category_id: category_a.id)

    assert_response :success
    assert_match in_category.description, response.body
    assert_no_match(/in category b/, response.body)
  end

  test "invalid date on update returns validation errors instead of raising" do
    sign_in(users(:one))
    category = finance_categories(:two)
    transaction = create_transaction(category: category, description: "keep the original date")
    original_date = transaction.transaction_date

    patch admin_finance_transaction_path(transaction), params: {
      finance_transaction: {
        transaction_type: "expense",
        finance_category_id: category.id,
        amount: transaction.amount,
        transaction_date: "not-a-date",
        payment_location: "cash",
        description: transaction.description
      }
    }

    assert_response :unprocessable_entity
    assert_equal original_date, transaction.reload.transaction_date
  end

  private

  def create_transaction(category:, description:)
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: category,
      finance_unit: finance_units(:main),
      recorded_by: users(:one),
      amount: 500,
      transaction_date: Date.current,
      payment_location: "cash",
      description: description
    )
  end

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
