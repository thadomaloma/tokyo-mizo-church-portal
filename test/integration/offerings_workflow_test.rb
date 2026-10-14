require "test_helper"

class OfferingsWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @unit = finance_units(:main)
    @tithe = FinanceCategory.create!(finance_unit: @unit, name: "Tithe (Sawm a Pakhat)", code: "tithe", category_type: "income",
                                     system_defined: true, description: FinanceCategory::SYSTEM_DESCRIPTION)
    @offering = finance_categories(:one)
    post user_session_path, params: { user: { email: users(:one).email, password: "password" } }
  end

  test "counters record a whole Sunday collection in one form" do
    get new_admin_offering_path(finance_unit_id: @unit.id)
    assert_response :success
    assert_select "input[name='amounts[#{@tithe.id}]']"

    assert_difference -> { @unit.finance_transactions.income.count }, 2 do
      post admin_offerings_path, params: {
        finance_unit_id: @unit.id, transaction_date: "2026-10-11", payment_location: "cash",
        counted_by: "Mawia, Zuali", amounts: { @tithe.id => "45,000", @offering.id => "12000" }
      }
    end

    assert_redirected_to admin_finance_transactions_path(finance_unit_id: @unit.id)
    assert_equal "11 October thawhlawm ¥57,000 save a ni.", flash[:notice]
    record = @unit.finance_transactions.find_by!(finance_category: @tithe)
    assert_equal 45_000, record.amount
    assert_equal "Pathianni thawhlawm · Chhiartu: Mawia, Zuali", record.description
  end

  test "an empty or invalid count saves nothing" do
    assert_no_difference -> { FinanceTransaction.count } do
      post admin_offerings_path, params: { finance_unit_id: @unit.id, transaction_date: "2026-10-11", amounts: { @tithe.id => "" } }
    end
    assert_response :unprocessable_entity

    assert_no_difference -> { FinanceTransaction.count } do
      post admin_offerings_path, params: { finance_unit_id: @unit.id, transaction_date: "2026-10-11", amounts: { @tithe.id => "12a" } }
    end
    assert_response :unprocessable_entity
  end

  test "a closed month rejects the collection" do
    FinancePeriod.create!(finance_unit: @unit, year: 2026, month: 10, status: :closed)

    assert_no_difference -> { FinanceTransaction.count } do
      post admin_offerings_path, params: { finance_unit_id: @unit.id, transaction_date: "2026-10-11", amounts: { @tithe.id => "100" } }
    end
    assert_response :unprocessable_entity
  end

  test "the monthly report reads like a treasurer statement" do
    @unit.finance_transactions.create!(transaction_type: "income", finance_category: @tithe, amount: 9_000,
                                       transaction_date: Date.new(2026, 10, 4), payment_location: "cash", recorded_by: users(:one))

    get admin_reports_path
    assert_redirected_to admin_finance_period_path(Date.current.year, Date.current.month)

    get admin_finance_period_path(2026, 10, finance_unit_id: @unit.id)
    assert_response :success
    assert_select "[data-statement]", text: /Balance hmasa.*Sum lut.*Tithe.*¥9,000.*Sum chhuak.*Balance tawp/m
  end
end
