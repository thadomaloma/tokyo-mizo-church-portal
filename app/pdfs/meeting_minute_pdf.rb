class MeetingMinutePdf
  include PdfRichText

  SECRETARY_SIGNATURE_FIT = [ 145, 48 ].freeze

  def initialize(meeting_minute)
    @meeting_minute = meeting_minute
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    register_fonts(pdf, family: "MinuteFont")

    build_header(pdf)
    build_details(pdf)
    build_attendance(pdf)
    build_minutes(pdf)
    build_footer(pdf)

    pdf.number_pages(
      "<page> / <total>",
      at: [ pdf.bounds.right - 50, 0 ],
      align: :right,
      size: 8
    )

    pdf.render
  end

  private

  attr_reader :meeting_minute

  def build_header(pdf)
    pdf.fill_color "0F172A"
    pdf.text "TOKYO MIZO CHURCH",
             size: 18,
             style: :bold,
             align: :center,
             character_spacing: 1.2

    pdf.move_down 6

    pdf.fill_color "334155"
    pdf.text meeting_minute.title,
             size: 15,
             style: :bold,
             align: :center

    pdf.move_down 10
    pdf.stroke_color "CBD5E1"
    pdf.line_width 1
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.fill_color "000000"
    pdf.move_down 16
  end

  def build_details(pdf)
    rows = detail_rows
    return if rows.empty?

    rows.each do |label, value|
      pdf.formatted_text [
        { text: "#{label}: ", styles: [ :bold ] },
        { text: value.to_s }
      ], size: 10
      pdf.move_down 4
    end

    pdf.move_down 16
  end

  def build_attendance(pdf)
    section(pdf, "Members Present", meeting_minute.attendees)
    section(pdf, "Members Absent / Apology", meeting_minute.absentees)
  end

  def build_minutes(pdf)
    [
      [ "Opening Prayer", meeting_minute.opening_prayer ],
      [ "Call to Order", meeting_minute.call_to_order ],
      [ "Reports", meeting_minute.reports ],
      [ "Previous Minute Approval", meeting_minute.previous_minutes ],
      [ "Agenda Items", meeting_minute.agenda_items ],
      [ "Decisions / Resolutions", meeting_minute.motions ],
      [ "Follow-up Actions", meeting_minute.action_items ],
      [ "Adjournment", meeting_minute.adjournment ]
    ].each do |title, body|
      section(pdf, title, body)
    end
  end

  def build_footer(pdf)
    rows = []

    if meeting_minute.next_meeting_date.present?
      rows << [ "Next Meeting Date", meeting_minute.next_meeting_date.strftime("%B %d, %Y") ]
    end

    return if rows.empty? && !meeting_minute.secretary_signature.attached? && meeting_minute.approved_by.blank?

    pdf.move_down 10
    rows.each do |label, value|
      pdf.formatted_text [
        { text: "#{label}: ", styles: [ :bold ] },
        { text: value.to_s }
      ], size: 10
      pdf.move_down 4
    end

    render_secretary_signature(pdf)
  end

  def section(pdf, title, body)
    return if plain_text(body).blank?

    pdf.move_down 4
    pdf.fill_color "0F172A"
    pdf.text title, size: 11, style: :bold
    pdf.fill_color "000000"
    pdf.move_down 5
    write_rich_text(pdf, body)
    pdf.move_down 12
  end

  def detail_rows
    [
      [ "Meeting Type", meeting_minute.meeting_type ],
      [ "Meeting Date", meeting_minute.meeting_date&.strftime("%B %d, %Y") ],
      [ "Time", time_text ],
      [ "Location", meeting_minute.location ],
      [ "Chairman", meeting_minute.chairperson ],
      [ "Secretary", meeting_minute.secretary_name.presence || meeting_minute.uploaded_by&.name ]
    ].select { |_label, value| value.present? }
  end

  def time_text
    [
      meeting_minute.start_time&.strftime("%I:%M %p"),
      meeting_minute.end_time&.strftime("%I:%M %p")
    ].compact.join(" - ")
  end

  def render_secretary_signature(pdf)
    return unless meeting_minute.secretary_signature.attached? || meeting_minute.approved_by.present?

    pdf.move_down 8

    signature_rendered = render_secretary_signature_image(pdf)
    if signature_rendered
      pdf.move_down 4
    end

    return if !signature_rendered && meeting_minute.approved_by.blank?

    pdf.formatted_text [
      { text: "Secretary Signature: ", styles: [ :bold ] },
      { text: meeting_minute.approved_by.to_s }
    ], size: 10
  end

  def render_secretary_signature_image(pdf)
    return false unless meeting_minute.secretary_signature.attached?

    meeting_minute.secretary_signature.open do |file|
      pdf.image file.path, fit: SECRETARY_SIGNATURE_FIT
    end

    true
  rescue ActiveStorage::FileNotFoundError, Errno::ENOENT => error
    Rails.logger.warn(
      "Skipping missing secretary signature for meeting minute " \
      "#{meeting_minute_identifier}: #{error.class} - #{error.message}"
    )
    false
  end

  def meeting_minute_identifier
    return meeting_minute.id if meeting_minute.respond_to?(:id) && meeting_minute.id.present?

    meeting_minute.title
  end
end
