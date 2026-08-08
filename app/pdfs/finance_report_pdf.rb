class FinanceReportPdf
  NAVY = "0F2942".freeze
  BLUE = "0369A1".freeze
  SLATE = "334155".freeze
  MUTED = "64748B".freeze
  BORDER = "CBD5E1".freeze
  PANEL = "F8FAFC".freeze
  INCOME = "047857".freeze
  INCOME_LIGHT = "ECFDF5".freeze
  EXPENSE = "BE123C".freeze
  EXPENSE_LIGHT = "FFF1F2".freeze

  def initialize(
    transactions:,
    income:,
    expense:,
    balance:,
    period_label: "This Year",
    period_year: Date.current.year,
    start_month: 1,
    end_month: Date.current.month,
    ledger_type_label: "All Transactions"
  )
    @transactions = transactions
    @income = income
    @expense = expense
    @balance = balance
    @period_label = period_label
    @ledger_type_label = ledger_type_label
    @report_data = FinanceReportData.new(
      transactions: transactions,
      income: income,
      expense: expense,
      balance: balance,
      period_year: period_year,
      start_month: start_month,
      end_month: end_month
    )
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    register_fonts(pdf)

    build_header(pdf)
    build_summary_and_chart(pdf)
    build_transactions(pdf)

    pdf.number_pages(
      "<page> / <total>",
      {
        at: [ pdf.bounds.right - 50, 0 ],
        align: :right,
        size: 8
      }
    )

    pdf.render
  end

  private

  attr_reader :transactions,
              :income,
              :expense,
              :balance,
              :period_label,
              :report_data,
              :ledger_type_label

  def register_fonts(pdf)
    font_path = unicode_font_path
    return unless font_path

    pdf.font_families.update(
      "FinanceReportFont" => {
        normal: font_path,
        bold: existing_font_path(bold_font_path(font_path)) || font_path,
        italic: font_path,
        bold_italic: existing_font_path(bold_font_path(font_path)) || font_path
      }
    )

    pdf.font "FinanceReportFont"
    @unicode_font_registered = true
  rescue StandardError => error
    @unicode_font_registered = false
    Rails.logger.warn("Finance PDF font registration failed: #{error.class} - #{error.message}")
  end

  def unicode_font_path
    [
      "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
      "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
      "/System/Library/Fonts/Supplemental/Arial.ttf",
      "/System/Library/Fonts/Hiragino Sans GB.ttc",
      "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.otf"
    ].find { |path| File.exist?(path) }
  end

  def bold_font_path(font_path)
    font_path
      .sub("Regular", "Bold")
      .sub("Sans.ttf", "Sans-Bold.ttf")
      .sub("Sans-Regular.ttf", "Sans-Bold.ttf")
      .sub("LiberationSans-Regular.ttf", "LiberationSans-Bold.ttf")
      .sub("Arial Unicode.ttf", "Arial Bold.ttf")
      .sub("Arial.ttf", "Arial Bold.ttf")
  end

  def existing_font_path(path)
    path if path && File.exist?(path)
  end

  def build_header(pdf)
    header_height = 96

    pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width, height: header_height) do
      pdf.fill_color NAVY
      pdf.fill_rectangle [ 0, header_height ], pdf.bounds.width, header_height

      pdf.fill_color "FFFFFF"
      pdf.move_down 16
      pdf.text "TOKYO MIZO CHURCH", size: 9, style: :bold, character_spacing: 1.4
      pdf.move_down 8
      pdf.text "Finance Report", size: 23, style: :bold
      pdf.move_down 5
      pdf.fill_color "BAE6FD"
      pdf.text "#{ledger_type_label}  |  #{period_label}", size: 10, style: :bold

      pdf.fill_color "CBD5E1"
      pdf.text_box "Generated #{Date.current.strftime('%B %d, %Y')}",
                   at: [ pdf.bounds.width - 180, header_height - 20 ],
                   width: 180,
                   size: 8,
                   align: :right
    end

    pdf.fill_color "000000"
    pdf.move_down 18
  end

  def build_summary_and_chart(pdf)
    pdf.fill_color NAVY
    pdf.text "PERIOD OVERVIEW", size: 9, style: :bold, character_spacing: 1.1
    pdf.move_down 8

    top = pdf.cursor
    summary_width = 252
    chart_gap = 18
    chart_width = pdf.bounds.width - summary_width - chart_gap
    summary_table = build_summary_table(pdf, summary_width)
    section_height = [ summary_table.height + 38, 164 ].max.ceil

    pdf.bounding_box([ 0, top ], width: summary_width, height: section_height) do
      draw_panel_background(pdf, summary_width, section_height)
      pdf.move_down 12
      pdf.indent(12) do
        pdf.fill_color SLATE
        pdf.text "Period Summary", size: 11, style: :bold
        pdf.move_down 8

        summary_table.draw
      end
    end

    pdf.bounding_box([ summary_width + chart_gap, top ], width: chart_width, height: section_height) do
      draw_panel_background(pdf, chart_width, section_height)
      pdf.move_down 12
      pdf.indent(12) do
        build_income_expense_chart(pdf, chart_width - 24)
      end
    end

    pdf.move_cursor_to(top - section_height)
    pdf.move_down 18

    pdf.fill_color NAVY
    pdf.text "MONTHLY GIVING", size: 9, style: :bold, character_spacing: 1.1
    pdf.move_down 6
    pdf.fill_color SLATE
    pdf.text "Monthly Tithe and Offering", size: 13, style: :bold
    pdf.move_down 7

    build_monthly_tithe_offering_table(pdf, pdf.bounds.width).draw
    pdf.fill_color "000000"
  end

  def build_income_expense_chart(pdf, width)
    pdf.fill_color SLATE
    pdf.text "Income vs Expense", size: 11, style: :bold
    pdf.move_down 6
    pdf.fill_color MUTED
    pdf.text "Movement during the selected period", size: 7.5
    pdf.move_down 14

    max_amount = report_data.chart_rows.map(&:last).max.to_f
    max_amount = 1 if max_amount.zero?
    amount_width = 80
    bar_width = width - amount_width
    bar_height = 9

    report_data.chart_rows.each do |label, amount|
      color = label == "Income" ? INCOME : EXPENSE
      pdf.fill_color SLATE
      pdf.text label, size: 8, style: :bold
      pdf.move_down 5

      pdf.fill_color "E2E8F0"
      pdf.fill_rounded_rectangle [ 0, pdf.cursor ], bar_width - 8, bar_height, 3
      fill_width = amount.zero? ? 0 : [ (amount.to_f / max_amount) * (bar_width - 8), 4 ].max
      if fill_width.positive?
        pdf.fill_color color
        pdf.fill_rounded_rectangle [ 0, pdf.cursor ], fill_width, bar_height, 3
      end

      pdf.fill_color color
      pdf.text_box yen(amount),
                   at: [ bar_width, pdf.cursor + 1 ],
                   width: amount_width,
                   height: 12,
                   size: 8.5,
                   style: :bold,
                   align: :right

      pdf.move_down 24
    end

    pdf.fill_color "000000"
  end

  def build_transactions(pdf)
    if transactions.size > 12
      pdf.start_new_page
    else
      pdf.move_down 18
    end
    pdf.fill_color NAVY
    pdf.text "TRANSACTION DETAIL", size: 9, style: :bold, character_spacing: 1.1
    pdf.move_down 6
    pdf.fill_color SLATE
    pdf.text "Transactions", size: 13, style: :bold
    pdf.fill_color MUTED
    pdf.text_box "#{transactions.size} records",
                 at: [ pdf.bounds.width - 100, pdf.cursor + 14 ],
                 width: 100,
                 size: 8,
                 align: :right
    pdf.move_down 8

    pdf.table(
      transaction_rows,
      header: true,
      column_widths: {
        0 => 68,
        1 => 52,
        2 => 82,
        3 => 58,
        4 => 180,
        5 => 80
      }
    ) do
      row(0).font_style = :bold
      row(0).background_color = NAVY
      row(0).text_color = "FFFFFF"

      cells.size = 7.5
      cells.padding = 5
      cells.border_width = 0

      rows(1..-1).each_with_index do |table_row, index|
        table_row.background_color = index.even? ? "FFFFFF" : PANEL
        table_row.border_bottom_width = 0.5
        table_row.border_bottom_color = "E2E8F0"
      end

      columns(0).nowrap = true
      columns(1).nowrap = true

      columns(1).align = :center
      columns(3).align = :center
      columns(5).align = :right
    end

    pdf.fill_color "000000"
  end

  def summary_rows
    report_data.summary_rows.map { |label, amount| [ label, yen(amount) ] }
  end

  def build_summary_table(pdf, width)
    pdf.make_table(summary_rows, width: width - 24, column_widths: [ 128, width - 152 ]) do
      cells.padding = [ 6, 7 ]
      cells.size = 7.5
      cells.border_width = 0
      cells.border_bottom_width = 0.5
      cells.border_bottom_color = "E2E8F0"

      row(0).background_color = INCOME_LIGHT
      row(0).text_color = INCOME
      row(1).background_color = EXPENSE_LIGHT
      row(1).text_color = EXPENSE
      row(2).background_color = "E0F2FE"
      row(2).text_color = BLUE
      rows(0..2).font_style = :bold
      columns(1).align = :right
    end
  end

  def monthly_tithe_offering_rows
    rows = [ [ "Month", "Tithe", "Offering" ] ]
    report_data.monthly_tithe_offering_rows.each do |month, tithe, offering|
      rows << [ month, yen(tithe), yen(offering) ]
    end
    totals = report_data.monthly_tithe_offering_rows.transpose
    rows << [ "Total", yen(totals[1]&.sum || 0), yen(totals[2]&.sum || 0) ]
    rows
  end

  def build_monthly_tithe_offering_table(pdf, width)
    rows = monthly_tithe_offering_rows

    pdf.make_table(rows, header: true, width: width, column_widths: [ width * 0.40, width * 0.30, width * 0.30 ]) do
      row(0).font_style = :bold
      row(0).background_color = NAVY
      row(0).text_color = "FFFFFF"

      cells.size = 7.5
      cells.padding = 5
      cells.border_width = 0
      rows(1..-2).each_with_index do |table_row, index|
        table_row.background_color = index.even? ? "FFFFFF" : PANEL
        table_row.border_bottom_width = 0.5
        table_row.border_bottom_color = "E2E8F0"
      end

      row(-1).font_style = :bold
      row(-1).background_color = "E0F2FE"
      row(-1).text_color = BLUE
      columns(1..2).align = :right
    end
  end

  def draw_panel_background(pdf, width, height)
    pdf.fill_color PANEL
    pdf.stroke_color "E2E8F0"
    pdf.fill_and_stroke_rounded_rectangle [ 0, height ], width, height, 8
    pdf.fill_color "000000"
    pdf.stroke_color "000000"
  end

  def transaction_rows
    rows = [
      [ "Date", "Type", "Category", "Location", "Description", "Amount" ]
    ]

    pdf_transactions.each do |transaction|
      rows << [
        transaction.transaction_date.strftime("%Y-%m-%d"),
        type_cell(transaction),
        safe_pdf_text(transaction.finance_category&.name || "-"),
        transaction.payment_location_bank? ? "Bank" : "Cash",
        safe_pdf_text(transaction.description.presence || "-"),
        yen(transaction.amount)
      ]
    end

    rows
  end

  def safe_pdf_text(value)
    text = value.to_s
    return text if @unicode_font_registered

    text.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
  end

  def pdf_transactions
    transactions.sort_by do |transaction|
      [
        transaction.transaction_date,
        transaction.created_at || Time.zone.at(0),
        transaction.id || 0
      ]
    end.reverse
  end

  def type_cell(transaction)
    if transaction.income?
      { content: "Income", text_color: "047857" }
    else
      { content: "Expense", text_color: "BE123C" }
    end
  end

  def yen(amount)
    "JPY #{amount.to_i.to_fs(:delimited)}"
  end
end
