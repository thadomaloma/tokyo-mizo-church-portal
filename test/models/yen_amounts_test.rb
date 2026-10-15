require "test_helper"

class YenAmountsTest < ActiveSupport::TestCase
  test "parses whole yen with commas, skips blanks and flags anything else" do
    amounts = YenAmounts.parse("1" => "12,000", "2" => " ", "3" => "4.5", "4" => "0")

    assert_equal({ 1 => 12_000, 3 => :invalid, 4 => 0 }, amounts)
    assert YenAmounts.invalid?(amounts)
    assert_not YenAmounts.invalid?(YenAmounts.parse("1" => "500"))
  end
end
