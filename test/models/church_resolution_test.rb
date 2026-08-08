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
end
