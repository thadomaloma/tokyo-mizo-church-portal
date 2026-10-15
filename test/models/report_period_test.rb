require "test_helper"

class ReportPeriodTest < ActiveSupport::TestCase
  test "reads and orders months from params, falling back to this year so far" do
    period = ReportPeriod.from_params({ year: "2026", start_month: "5", end_month: "2" }, today: Date.new(2026, 10, 16))
    assert_equal [ 2026, 2, 5 ], [ period.year, period.start_month, period.end_month ]
    assert_equal Date.new(2026, 2, 1)..Date.new(2026, 5, 31), period.range

    default = ReportPeriod.from_params({}, today: Date.new(2026, 10, 16))
    assert_equal [ 2026, 1, 10 ], [ default.year, default.start_month, default.end_month ]
  end

  test "labels a single month and a range" do
    assert_equal "March 2026", ReportPeriod.new(2026, 3, 3).label
    assert_equal "January - May 2026, up to May", ReportPeriod.new(2026, 1, 5).caption
  end

  test "the previous period has the same length and may cross into last year" do
    period = ReportPeriod.new(2026, 1, 3)
    assert_equal Date.new(2025, 10, 1)...Date.new(2026, 1, 1), period.previous_range
    assert_equal "October - December 2025", period.previous_label
  end
end
