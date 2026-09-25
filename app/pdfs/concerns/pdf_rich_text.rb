# Shared Prawn helpers for Secretary Workspace PDFs (Meeting Minutes,
# Official Letters, Resolutions): a Unicode-capable font loader and a
# minimal HTML -> Prawn inline-markup converter for the contenteditable
# rich text produced by `_rich_text_area.html.erb`.
module PdfRichText
  private

  def register_fonts(pdf, family: "DocumentFont")
    regular = [
      "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
      "/System/Library/Fonts/Supplemental/Arial.ttf",
      "/System/Library/Fonts/Supplemental/Times New Roman.ttf"
    ].find { |path| File.exist?(path) }
    return unless regular

    bold = regular.sub(/(?:Regular)?\.ttf\z/, "Bold.ttf")
    bold = regular unless File.exist?(bold)

    pdf.font_families.update(
      family => {
        normal: regular,
        bold: bold,
        italic: regular,
        bold_italic: bold
      }
    )
    pdf.font family
  rescue StandardError => error
    Rails.logger.warn("PDF font registration failed: #{error.class} - #{error.message}")
  end

  def plain_text(value)
    text = value.to_s
    text = text.gsub(%r{</(p|div|li|h[1-6])>}i, "\n")
    text = text.gsub(%r{<br\s*/?>}i, "\n")
    text = text.gsub(%r{<li[^>]*>}i, "- ")
    text = ActionView::Base.full_sanitizer.sanitize(text)
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  def write_rich_text(pdf, value, size: 10, leading: 4, align: :left, paragraph_gap: 0)
    if html_content?(value)
      rich_blocks(value).each_with_index do |block, index|
        pdf.move_down paragraph_gap if index.positive? && paragraph_gap.positive?
        pdf.text block, size: size, leading: leading, inline_format: true, align: align
      end
    else
      pdf.text decoded_text(value), size: size, leading: leading, align: align
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
end
