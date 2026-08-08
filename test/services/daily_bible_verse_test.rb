require "test_helper"

class DailyBibleVerseTest < ActiveSupport::TestCase
  test "ships with a substantial curated local collection" do
    assert_operator DailyBibleVerse.verses.length, :>=, 100

    DailyBibleVerse.verses.each do |verse|
      assert_predicate verse.reference, :present?
      assert_predicate verse.text, :present?
      assert_predicate verse.theme, :present?
    end
  end

  test "returns the same verse throughout a date" do
    date = Date.new(2026, 8, 8)

    assert_equal DailyBibleVerse.for(date), DailyBibleVerse.for(date)
  end

  test "rotates predictably on the following date" do
    date = Date.new(2026, 8, 8)

    assert_not_equal DailyBibleVerse.for(date), DailyBibleVerse.for(date.next_day)
  end
end
