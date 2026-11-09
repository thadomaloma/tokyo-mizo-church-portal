require "test_helper"

class AppBuildTest < ActiveSupport::TestCase
  test "reads the commit and build time written by the Dockerfile" do
    build = AppBuild.new("aa20ff9d3c1e2f\n2026-11-09T01:30:00Z\n")

    assert_equal "aa20ff9", build.commit
    assert_equal Time.zone.parse("2026-11-09 10:30"), build.built_at
  end

  test "falls back to Railway's variable and copes with a missing file" do
    assert_equal "1234567", AppBuild.new("\n\n", fallback_commit: "1234567890").commit
    assert_nil AppBuild.new("").built_at
    assert_nil AppBuild.new("").commit
  end
end
