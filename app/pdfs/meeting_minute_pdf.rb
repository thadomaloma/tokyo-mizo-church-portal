class MeetingMinutePdf
  def initialize(meeting_minute)
    @meeting_minute = meeting_minute
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    register_fonts(pdf)

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

  def register_fonts(pdf)
    regular = "/System/Library/Fonts/Supplemental/Times New Roman.ttf"
    bold = "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf"
    italic = "/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf"
    bold_italic = "/System/Library/Fonts/Supplemental/Times New Roman Bold Italic.ttf"

    return unless [ regular, bold, italic, bold_italic ].all? { |font| File.exist?(font) }

    pdf.font_families.update(
      "MinuteFont" => {
        normal: regular,
        bold: bold,
        italic: italic,
        bold_italic: bold_italic
      }
    )
    pdf.font "MinuteFont"
  end

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

  def plain_text(value)
    text = value.to_s
    text = text.gsub(%r{</(p|div|li|h[1-6])>}i, "\n")
    text = text.gsub(%r{<br\s*/?>}i, "\n")
    text = text.gsub(%r{<li[^>]*>}i, "- ")
    text = ActionView::Base.full_sanitizer.sanitize(text)
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  def write_rich_text(pdf, value)
    if html_content?(value)
      rich_blocks(value).each do |block|
        pdf.text block, size: 10, leading: 4, inline_format: true
      end
    else
      pdf.text decoded_text(value), size: 10, leading: 4
    end
  end

  def html_content?(value)
    value.to_s.match?(/<\/?[a-z][\s\S]*>/i)
  end

  def rich_blocks(value)
    fragment = Nokogiri::HTML::DocumentFragment.parse(sanitized_html(value))
    blocks = nodes_to_blocks(fragment.children)
    blocks.map(&:strip).reject(&:blank?)
  end

  def sanitized_html(value)
    ActionController::Base.helpers.sanitize(
      value.to_s,
      tags: %w[p br div strong b em i u ul ol li],
      attributes: []
    )
  end

  def nodes_to_blocks(nodes)
    blocks = []

    nodes.each do |node|
      case node.name
      when "p", "div"
        content = inline_markup(node.children)
        blocks << content if content.present?
      when "ul", "ol"
        blocks.concat(list_blocks(node))
      when "br"
        blocks << ""
      when "text"
        content = escape_pdf_markup(node.text.strip)
        blocks << content if content.present?
      else
        content = inline_markup([ node ])
        blocks << content if content.present?
      end
    end

    blocks
  end

  def list_blocks(list_node)
    list_node.css("> li").each_with_index.map do |item, index|
      prefix = list_node.name == "ol" ? "#{index + 1}. " : "- "
      "#{prefix}#{inline_markup(item.children)}"
    end
  end

  def inline_markup(nodes)
    nodes.map do |node|
      case node.name
      when "text"
        escape_pdf_markup(node.text)
      when "strong", "b"
        "<b>#{inline_markup(node.children)}</b>"
      when "em", "i"
        "<i>#{inline_markup(node.children)}</i>"
      when "u"
        "<u>#{inline_markup(node.children)}</u>"
      when "br"
        "\n"
      when "ul", "ol"
        list_blocks(node).join("\n")
      when "li"
        inline_markup(node.children)
      else
        inline_markup(node.children)
      end
    end.join
  end

  def escape_pdf_markup(text)
    decoded_text(text)
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
  end

  def decoded_text(value)
    CGI.unescapeHTML(value.to_s).strip
  end

  def render_secretary_signature(pdf)
    return unless meeting_minute.secretary_signature.attached? || meeting_minute.approved_by.present?

    pdf.move_down 8

    if meeting_minute.secretary_signature.attached?
      meeting_minute.secretary_signature.open do |file|
        pdf.image file.path, fit: [ 170, 70 ]
      end

      pdf.move_down 4
    end

    pdf.formatted_text [
      { text: "Secretary Signature: ", styles: [ :bold ] },
      { text: meeting_minute.approved_by.to_s }
    ], size: 10
  end
end
