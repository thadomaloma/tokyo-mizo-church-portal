require "test_helper"

class AdminRouteIntegrityTest < ActionDispatch::IntegrationTest
  test "finance resources do not expose unimplemented show routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/finance_categories/1", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/finance_transactions/1", method: :get)
    end
  end
end
