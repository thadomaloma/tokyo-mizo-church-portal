require "test_helper"

class ChurchResolutionTest < ActiveSupport::TestCase
  test "requires a title" do
    resolution = ChurchResolution.new(status: :pending, priority: :normal)

    assert_not resolution.valid?
    assert_includes resolution.errors[:title], "can't be blank"
  end

  test "keeps completed at synchronized with status" do
    resolution = ChurchResolution.create!(
      title: "Repair sound system",
      status: :completed,
      priority: :normal
    )

    assert resolution.completed_at.present?

    resolution.update!(status: :in_progress)

    assert_nil resolution.completed_at
  end

  test "assigns a sequential, year-scoped, human readable number on create" do
    first = ChurchResolution.create!(title: "First", status: :pending, priority: :normal)
    second = ChurchResolution.create!(title: "Second", status: :pending, priority: :normal)

    assert_match(/\ARES-\d{4}-\d{3}\z/, first.number)
    assert_equal first.number.split("-").last.to_i + 1, second.number.split("-").last.to_i
  end

  test "does not allow duplicate numbers" do
    resolution = ChurchResolution.create!(title: "Original", status: :pending, priority: :normal)
    duplicate = ChurchResolution.new(title: "Duplicate", status: :pending, priority: :normal, number: resolution.number)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end

  test "keeps its number stable across updates" do
    resolution = ChurchResolution.create!(title: "Stable", status: :pending, priority: :normal)
    original_number = resolution.number

    resolution.update!(title: "Renamed")

    assert_equal original_number, resolution.reload.number
  end

  test "due_soon includes items due within 7 days but excludes completed and overdue items" do
    due_today = create_resolution(due_date: Date.current)
    due_in_seven = create_resolution(due_date: 7.days.from_now.to_date)
    due_in_eight = create_resolution(due_date: 8.days.from_now.to_date)
    already_overdue = create_resolution(due_date: 1.day.ago.to_date)
    due_soon_but_completed = create_resolution(due_date: 3.days.from_now.to_date, status: :completed)

    results = ChurchResolution.due_soon

    assert_includes results, due_today
    assert_includes results, due_in_seven
    assert_not_includes results, due_in_eight
    assert_not_includes results, already_overdue
    assert_not_includes results, due_soon_but_completed
  end

  test "overdue? mirrors the overdue scope for a single record" do
    overdue = create_resolution(due_date: 1.day.ago.to_date)
    not_due_yet = create_resolution(due_date: 1.day.from_now.to_date)
    completed_but_past_due = create_resolution(due_date: 1.day.ago.to_date, status: :completed)
    no_due_date = create_resolution(due_date: nil)

    assert overdue.overdue?
    assert_not not_due_yet.overdue?
    assert_not completed_but_past_due.overdue?
    assert_not no_due_date.overdue?
  end

  private

  def create_resolution(due_date:, status: :pending)
    ChurchResolution.create!(
      title: "Resolution #{SecureRandom.hex(4)}",
      status: status,
      priority: :normal,
      due_date: due_date
    )
  end
end
