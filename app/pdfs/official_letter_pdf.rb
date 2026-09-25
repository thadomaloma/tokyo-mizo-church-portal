class OfficialLetterPdf
  include PdfRichText

  NAVY = "173A5E".freeze
  INK = "172033".freeze
  MUTED = "64748B".freeze
  BORDER = "CBD5E1".freeze

  def initialize(official_letter)
    @official_letter = official_letter
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: [ 46, 52, 58, 52 ])
    register_fonts(pdf, family: "LetterFont")

    build_header(pdf)
    build_reference_line(pdf)
    build_recipient(pdf)
    build_subject(pdf)
    build_body(pdf)
    build_closing(pdf)
    build_page_footer(pdf)

    pdf.render
  end

  private

  attr_reader :official_letter

  def build_header(pdf)
    top = pdf.cursor
    left_width = 130
    right_width = 140
    center_width = pdf.bounds.width - left_width - right_width
    logo = Rails.root.join("app/assets/images/tokyo_mizo_church_logo_print.png")
    pdf.image logo.to_s, at: [ 8, top ], fit: [ 60, 60 ] if logo.exist?

    pdf.bounding_box([ left_width, top ], width: center_width, height: 68) do
      pdf.fill_color NAVY
      pdf.text "TOKYO MIZO CHURCH",
               size: 15,
               style: :bold,
               align: :center,
               character_spacing: 0.8
      pdf.move_down 4
      pdf.fill_color MUTED
      pdf.text "TOKYO, JAPAN", size: 8, style: :bold, align: :center, character_spacing: 1.5
      pdf.move_down 5
      draw_contact_line(pdf, :email, official_letter.effective_header_email)
      draw_contact_line(pdf, :website, official_letter.effective_header_website)
    end

    pdf.bounding_box([ pdf.bounds.width - right_width, top ], width: right_width, height: 68) do
      pdf.fill_color INK
      draw_officer_block(
        pdf,
        "President",
        official_letter.header_president_name,
        official_letter.local_president_phone
      )
      draw_officer_block(
        pdf,
        "Secretary",
        official_letter.header_secretary_name,
        official_letter.local_secretary_phone
      )
    end

    pdf.move_cursor_to(top - 74)
    pdf.stroke_color NAVY
    pdf.line_width 2.2
    pdf.stroke_horizontal_rule
    pdf.fill_color INK
    pdf.move_down 15
  end

  def draw_contact_line(pdf, kind, value)
    y = pdf.cursor
    pdf.stroke_color NAVY
    pdf.line_width 0.7

    if kind == :email
      pdf.stroke_rectangle [ 5, y ], 4.5, 3.4
      pdf.stroke_line [ 5, y ], [ 7.25, y - 1.7 ]
      pdf.stroke_line [ 9.5, y ], [ 7.25, y - 1.7 ]
    else
      pdf.stroke_circle [ 7.25, y - 2 ], 2
      pdf.stroke_line [ 5.25, y - 2 ], [ 9.25, y - 2 ]
      pdf.stroke_line [ 7.25, y ], [ 7.25, y - 4 ]
    end

    pdf.fill_color MUTED
    pdf.text_box value.to_s, at: [ 12, y + 1 ], width: pdf.bounds.width - 12, height: 9, size: 6.7
    pdf.move_down 10
  end

  def draw_officer_block(pdf, label, name, phone)
    return if name.blank? && phone.blank?

    if name.present?
      pdf.formatted_text [
        { text: "#{label}: ", styles: [ :bold ] },
        { text: name.to_s }
      ], size: 7.2, align: :right
    end

    if phone.present?
      pdf.fill_color NAVY
      pdf.text "+81 #{phone}", size: 7, style: :bold, align: :right
      pdf.fill_color INK
    end

    pdf.move_down 4
  end

  def build_reference_line(pdf)
    y = pdf.cursor
    pdf.bounding_box([ 0, y ], width: pdf.bounds.width / 2, height: 16) do
      pdf.formatted_text [
        { text: "Ref No: ", styles: [ :bold ] },
        { text: official_letter.reference_number.to_s }
      ], size: 9
    end

    pdf.bounding_box([ pdf.bounds.width / 2, y ], width: pdf.bounds.width / 2, height: 16) do
      pdf.formatted_text [
        { text: "Date: ", styles: [ :bold ] },
        { text: official_letter.letter_date&.strftime("%B %d, %Y").to_s }
      ], size: 9, align: :right
    end

    pdf.move_cursor_to(y - 18)
  end

  def build_recipient(pdf)
    pdf.move_down 18
    pdf.text "To,", size: 10, style: :bold
    pdf.indent(24) do
      pdf.move_down 3
      pdf.text official_letter.recipient_name.to_s, size: 10, style: :italic
      pdf.text official_letter.recipient_organization.to_s, size: 10, style: :bold if official_letter.recipient_organization.present?

      official_letter.recipient_address.to_s.each_line do |line|
        pdf.text line.strip, size: 10 if line.strip.present?
      end
    end
    pdf.move_down 22
  end

  def build_subject(pdf)
    pdf.formatted_text [
      { text: "Subject : ", styles: [ :bold ] },
      { text: official_letter.subject.to_s, styles: [ :bold ] }
    ], size: 10
    pdf.move_down 22
  end

  def build_body(pdf)
    pdf.text official_letter.effective_salutation, size: 10, style: :bold
    pdf.move_down 13

    pdf.indent(24) do
      write_rich_text(
        pdf,
        official_letter.body,
        size: 10,
        leading: 5,
        align: :justify,
        paragraph_gap: 7
      ) if official_letter.body.present?
    end

    pdf.move_down 24
  end

  def build_closing(pdf)
    pdf.bounding_box([ pdf.bounds.width - 190, pdf.cursor ], width: 190) do
      pdf.text official_letter.effective_closing_line, size: 10
      pdf.move_down 38

      if official_letter.signatory_name.present?
        pdf.stroke_color BORDER
        pdf.stroke_horizontal_rule
        pdf.move_down 4
        pdf.fill_color INK
        pdf.text official_letter.signatory_name, size: 10, style: :bold
      end

      pdf.text official_letter.signatory_role, size: 9 if official_letter.signatory_role.present?
      pdf.text "Tokyo Mizo Church", size: 9, style: :bold
    end
  end

  def build_page_footer(pdf)
    pdf.fill_color MUTED
    pdf.number_pages(
      "TOKYO MIZO CHURCH - OFFICIAL CORRESPONDENCE    |    PAGE <page> OF <total>",
      at: [ 0, -24 ],
      width: pdf.bounds.width,
      align: :center,
      size: 7
    )
  end
end
