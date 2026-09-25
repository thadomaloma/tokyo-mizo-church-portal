class ChurchResolutionPdf
  include PdfRichText

  def initialize(church_resolution)
    @church_resolution = church_resolution
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    register_fonts(pdf, family: "ResolutionFont")

    build_header(pdf)
    build_details(pdf)
    build_decision(pdf)

    pdf.render
  end

  private

  attr_reader :church_resolution

  def build_header(pdf)
    pdf.fill_color "0F172A"
    pdf.text "TOKYO MIZO CHURCH", size: 18, style: :bold, align: :center, character_spacing: 1.2

    pdf.move_down 4
    pdf.fill_color "334155"
    pdf.text "CHURCH RESOLUTION", size: 12, style: :bold, align: :center, character_spacing: 1

    pdf.move_down 10
    pdf.stroke_color "CBD5E1"
    pdf.line_width 1
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.fill_color "000000"
    pdf.move_down 16
  end

  def build_details(pdf)
    pdf.fill_color "0F172A"
    pdf.text church_resolution.number, size: 11, style: :bold
    pdf.move_down 2
    pdf.fill_color "000000"
    pdf.text church_resolution.title, size: 15, style: :bold
    pdf.move_down 12

    detail_rows.each do |label, value|
      pdf.formatted_text [
        { text: "#{label}: ", styles: [ :bold ] },
        { text: value.to_s }
      ], size: 10
      pdf.move_down 4
    end

    pdf.move_down 12
  end

  def build_decision(pdf)
    return if church_resolution.description.blank?

    pdf.fill_color "0F172A"
    pdf.text "Decision", size: 11, style: :bold
    pdf.fill_color "000000"
    pdf.move_down 5
    write_rich_text(pdf, church_resolution.description)
  end

  def detail_rows
    [
      [ "Status", church_resolution.status&.humanize ],
      [ "Priority", church_resolution.priority&.humanize ],
      [ "Originating Meeting", church_resolution.meeting_minute&.title ],
      [ "Responsible Person", church_resolution.assigned_to&.name ],
      [ "Due Date", church_resolution.due_date&.strftime("%B %d, %Y") ]
    ].select { |_label, value| value.present? }
  end
end
