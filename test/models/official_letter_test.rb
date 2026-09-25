require "test_helper"

class OfficialLetterTest < ActiveSupport::TestCase
  test "requires recipient name, subject and letter date" do
    letter = OfficialLetter.new(status: :draft, created_by: users(:one))

    assert_not letter.valid?
    assert_includes letter.errors[:recipient_name], "can't be blank"
    assert_includes letter.errors[:subject], "can't be blank"
    assert_includes letter.errors[:letter_date], "can't be blank"
  end

  test "assigns a sequential, year-scoped, human readable reference number on create" do
    first = OfficialLetter.create!(
      recipient_name: "First Recipient",
      subject: "First Subject",
      letter_date: Date.current,
      created_by: users(:one)
    )
    second = OfficialLetter.create!(
      recipient_name: "Second Recipient",
      subject: "Second Subject",
      letter_date: Date.current,
      created_by: users(:one)
    )

    assert_match(%r{\ATMC/\d{4}/\d{3}\z}, first.reference_number)
    assert_equal first.reference_number.split("/").last.to_i + 1, second.reference_number.split("/").last.to_i
  end

  test "reference number uses the letter date year" do
    letter = OfficialLetter.create!(
      recipient_name: "Backdated Recipient",
      subject: "Backdated Subject",
      letter_date: Date.new(2024, 12, 20),
      created_by: users(:one)
    )

    assert_match(%r{\ATMC/2024/\d{3}\z}, letter.reference_number)
  end

  test "provides editable Mizo correspondence defaults" do
    letter = OfficialLetter.new

    assert_equal "OFFICIAL LETTER", letter.document_heading
    assert_equal "Rawngbawlpui duhtak,", letter.effective_salutation
    assert_equal "Lawmthu nen,", letter.effective_closing_line
    assert_equal "admin@tokyomizochurch.org", letter.effective_header_email
    assert_equal "tokyomizochurch.org", letter.effective_header_website
  end

  test "normalizes Japan country code for letterhead display" do
    letter = OfficialLetter.new(
      header_president_phone: "+81 90 1111 2222",
      header_secretary_phone: "81-90-3333-4444"
    )

    assert_equal "90 1111 2222", letter.local_president_phone
    assert_equal "90-3333-4444", letter.local_secretary_phone
  end

  test "does not allow duplicate reference numbers" do
    letter = OfficialLetter.create!(
      recipient_name: "Recipient",
      subject: "Subject",
      letter_date: Date.current,
      created_by: users(:one)
    )
    duplicate = OfficialLetter.new(
      recipient_name: "Other",
      subject: "Other",
      letter_date: Date.current,
      created_by: users(:one),
      reference_number: letter.reference_number
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:reference_number], "has already been taken"
  end

  test "can optionally link to a church resolution" do
    resolution = ChurchResolution.create!(title: "Linked", status: :pending, priority: :normal)
    letter = OfficialLetter.create!(
      recipient_name: "Recipient",
      subject: "Subject",
      letter_date: Date.current,
      created_by: users(:one),
      church_resolution: resolution
    )

    assert_equal resolution, letter.church_resolution
    assert_equal letter, resolution.reload.official_letter
  end

  test "does not require a related resolution" do
    letter = OfficialLetter.new(
      recipient_name: "Recipient",
      subject: "Subject",
      letter_date: Date.current,
      created_by: users(:one)
    )

    assert letter.valid?
  end
end
