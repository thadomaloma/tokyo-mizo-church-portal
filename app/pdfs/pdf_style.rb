# The look shared by the finance PDFs: warm neutrals, hairline rules,
# Newsreader for headline figures and Inter for everything else. Colour only
# marks money in (green) and out (red); amounts also carry +/− signs so a
# report still reads correctly printed in black & white.
module PdfStyle
  INK = "1A2433".freeze
  SOFT = "3D4757".freeze
  MUTED = "687385".freeze
  LINE = "E3E8EE".freeze
  SUNKEN = "F5F7FA".freeze
  BRAND = "16305A".freeze
  MONEY_IN = "2F7552".freeze
  MONEY_OUT = "A8432F".freeze

  FONT_DIR = Rails.root.join("vendor/fonts")
  LOGO_PATH = Rails.root.join("vendor/images/pdf-logo.png")

  private

  def register_fonts(pdf)
    pdf.font_families.update(
      "Inter" => {
        normal: FONT_DIR.join("Inter-Regular.ttf").to_s,
        medium: FONT_DIR.join("Inter-Medium.ttf").to_s,
        bold: FONT_DIR.join("Inter-SemiBold.ttf").to_s
      },
      "Newsreader" => {
        normal: FONT_DIR.join("Newsreader-Regular.ttf").to_s,
        bold: FONT_DIR.join("Newsreader-Medium.ttf").to_s
      }
    )
    pdf.font "Inter"
    register_cjk_fallback(pdf)
  end

  # Descriptions may contain Japanese, so glyphs missing from Inter fall
  # back to the bundled Noto Sans JP (only the glyphs used get embedded).
  def register_cjk_fallback(pdf)
    path = FONT_DIR.join("NotoSansJP-Regular.ttf").to_s
    pdf.font_families.update("NotoSansJP" => { normal: path, medium: path, bold: path })
    pdf.fallback_fonts([ "NotoSansJP" ])
  end

  def style_table(table)
    table.cells.size = 8.5
    table.cells.padding = [ 6.5, 6, 6.5, 6 ]
    table.cells.borders = [ :bottom ]
    table.cells.border_width = 0.5
    table.cells.border_color = LINE
    table.cells.text_color = SOFT
    table.cells.valign = :center

    table.row(0).size = 7
    table.row(0).text_color = MUTED
    table.row(0).character_spacing = 0.8
    table.row(0).font_style = :medium
    table.row(0).background_color = SUNKEN
    table.row(0).border_color = LINE
    table.row(0).padding = [ 6, 6, 6, 6 ]
    table.row(0).each { |cell| cell.content = cell.content.upcase }

    table.columns(0).padding_left = 0
    table.row(0).columns(0).padding_left = 6
  end

  def section_title(pdf, title)
    pdf.font("Newsreader") { pdf.text title, size: 13, color: INK }
    pdf.move_down 9
  end

  def hairline(pdf, color: LINE, width: 0.5)
    pdf.stroke_color color
    pdf.line_width width
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.stroke_color INK
  end

  def ensure_space(pdf, needed)
    pdf.start_new_page if pdf.cursor < needed
  end

  def money(amount, sign: :auto)
    amount = amount.to_i
    prefix = case sign
    when :plus then "+"
    when :minus then "−"
    else amount.negative? ? "−" : ""
    end
    "#{prefix}¥#{amount.abs.to_fs(:delimited)}"
  end

  def signed(amount)
    return money(0) if amount.to_i.zero?

    money(amount, sign: amount.negative? ? :minus : :plus)
  end

  def clean(text)
    text.to_s.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "")
  end

  def escape(text)
    ERB::Util.html_escape(text)
  end
end
