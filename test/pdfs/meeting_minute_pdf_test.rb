require "test_helper"

class MeetingMinutePdfTest < ActiveSupport::TestCase
  MissingSignature = Struct.new do
    def attached?
      true
    end

    def open
      raise ActiveStorage::FileNotFoundError
    end
  end

  FakeMinute = Struct.new(
    :id,
    :title,
    :meeting_type,
    :meeting_date,
    :location,
    :chairperson,
    :secretary_name,
    :uploaded_by,
    :secretary_signature,
    :approved_by,
    keyword_init: true
  ) do
    def start_time = nil
    def end_time = nil
    def attendees = "1. Test Member - Member"
    def absentees = nil
    def opening_prayer = nil
    def call_to_order = nil
    def reports = nil
    def previous_minutes = nil
    def agenda_items = nil
    def motions = nil
    def action_items = nil
    def adjournment = nil
    def next_meeting_date = nil
  end

  test "renders even when attached secretary signature file is missing" do
    minute = FakeMinute.new(
      id: 123,
      title: "June Inkhawm Thuziak – Pathian malsawmna",
      meeting_type: "OB Meeting",
      meeting_date: Date.current,
      location: "Tokyo",
      chairperson: "Chairperson",
      secretary_name: "Secretary",
      secretary_signature: MissingSignature.new,
      approved_by: "Secretary"
    )

    pdf = MeetingMinutePdf.new(minute).render

    assert pdf.start_with?("%PDF")
  end
end
