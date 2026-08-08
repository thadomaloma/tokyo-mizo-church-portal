require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "health endpoint is public" do
    get rails_health_check_path

    assert_response :success
  end
end
