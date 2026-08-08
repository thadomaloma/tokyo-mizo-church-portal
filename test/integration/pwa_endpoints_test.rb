require "test_helper"

class PwaEndpointsTest < ActionDispatch::IntegrationTest
  test "manifest is publicly available" do
    get pwa_manifest_path

    assert_response :success
    assert_includes response.media_type, "application/json"
  end

  test "service worker is publicly available as javascript" do
    get pwa_service_worker_path

    assert_response :success
    assert_match(/javascript/, response.media_type)
  end
end
