# The year-end report for the church meeting (see AnnualReport): balances,
# income and expenses by category against the budget and the year before,
# the year month by month, and lines for the treasurer and chairman to sign.
class AnnualReportPdf
  include PdfStyle

  def initialize(report)
    @report = report
    @unit = report.finance_unit
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: [ 54, 48, 64, 48 ], info: document_info)
    register_fonts(pdf)

    draw_cover(pdf)
    draw_summary(pdf)
    draw_balances(pdf)
    draw_income(pdf)
    draw_expenses(pdf)
    draw_monthly(pdf)
    draw_signatures(pdf)
    draw_page_furniture(pdf)

    pdf.render
  end

  private

  attr_reader :report, :unit

  def document_info
    { Title: "Tokyo Mizo Church annual report — #{report.label}", Author: "Tokyo Mizo Church", Creator: "Tokyo Mizo Church Finance" }
  end

  def draw_cover(pdf)
    top = pdf.cursor
    pdf.image LOGO_PATH.to_s, at: [ 0, top ], width: 30 if File.exist?(LOGO_PATH)

    pdf.bounding_box([ 40, top + 1 ], width: 260) do
      pdf.font("Newsreader") { pdf.text "Tokyo Mizo Church", size: 15, color: INK }
      pdf.text "ANNUAL FINANCE REPORT", size: 7, color: MUTED, character_spacing: 1.2
    end
    pdf.bounding_box([ pdf.bounds.width - 220, top ], width: 220) do
      pdf.text unit.name, size: 9, color: INK, align: :right, style: :medium
      pdf.text "Generated #{Date.current.strftime('%-d %B %Y')}", size: 7.5, color: MUTED, align: :right
    end

    pdf.move_cursor_to(top - 44)
    hairline(pdf)
    pdf.move_down 26
    pdf.text "YEAR", size: 7.5, color: MUTED, character_spacing: 1.2
    pdf.move_down 4
    pdf.font("Newsreader") { pdf.text report.label, size: 30, color: INK }
    pdf.move_down 6
    comparison = report.previous? ? "Compared with #{report.previous_label}." : "There are no entries for #{report.year - 1} to compare with."
    pdf.text "#{comparison} Opening balances are money brought forward, not income.", size: 8, color: MUTED
    pdf.move_down 18
  end

  def draw_summary(pdf)
    columns = [
      [ "Opening balance", money(report.opening_balance), INK, nil ],
      [ "Income", money(report.income, sign: :plus), MONEY_IN, (change(report.income, report.previous_income) if report.previous?) ],
      [ "Expenses", money(report.expense, sign: :minus), MONEY_OUT, (change(report.expense, report.previous_expense) if report.previous?) ],
      [ "Closing balance", money(report.closing_balance), INK, nil ]
    ]
    width = pdf.bounds.width / columns.size
    top = pdf.cursor
    height = 70

    hairline(pdf, color: INK, width: 0.8)
    columns.each_with_index do |(label, value, color, note), index|
      x = index * width
      pdf.bounding_box([ x + (index.zero? ? 0 : 12), top - 12 ], width: width - 12, height: height - 12) do
        pdf.text label, size: 8, color: MUTED
        pdf.move_down 6
        pdf.font("Newsreader") { pdf.text value, size: 17, color: color }
        pdf.text note, size: 7, color: MUTED if note
      end
      next if index.zero?

      pdf.stroke_color LINE
      pdf.line_width 0.5
      pdf.stroke_line [ x, top - 10 ], [ x, top - height + 6 ]
    end
    pdf.move_cursor_to(top - height)
    hairline(pdf)
    pdf.move_down 14
  end

  def draw_balances(pdf)
    balances = report.account_balances
    text = FinanceTransaction::LOCATIONS.map { |location| "#{unit.account_label(location)} #{money(balances[location])}" }.join("   ·   ")
    pdf.text "Held on #{report.end_date.strftime('%-d %B %Y')}:   #{text}", size: 8.5, color: SOFT
    pdf.move_down 24
  end

  def draw_income(pdf)
    ensure_space(pdf, 140)
    section_title(pdf, "Income by category")
    previous = report.previous?
    data = [ [ "Category", report.year.to_s, *([ report.previous_label, "Change" ] if previous) ] ]
    report.income_lines.each do |line|
      data << [ clean(line.name), money(line.amount), *([ money(line.previous), percent(line.amount, line.previous) ] if previous) ]
    end
    data << [ "Total", money(report.income), *([ money(report.previous_income), percent(report.income, report.previous_income) ] if previous) ]
    table(pdf, data, money_columns: 1..(data.first.size - 1))
  end

  def draw_expenses(pdf)
    ensure_space(pdf, 140)
    section_title(pdf, "Expenses by category")
    previous = report.previous?
    data = [ [ "Category", report.year.to_s, "Budget", "Used", *(report.previous_label if previous) ] ]
    report.expense_lines.each do |line|
      data << [ clean(line.name), money(line.amount), line.budget ? money(line.budget) : "—",
                line.budget_used ? "#{line.budget_used}%" : "—", *(money(line.previous) if previous) ]
    end
    budget = report.budget_total
    data << [ "Total", money(report.expense), budget.positive? ? money(budget) : "—",
              budget.positive? ? "#{((report.expense * 100.0) / budget).round}%" : "—", *(money(report.previous_expense) if previous) ]
    table(pdf, data, money_columns: 1..(data.first.size - 1)) do |t|
      t.column(3).rows(1..-1).each { |cell| cell.text_color = MONEY_OUT if cell.content.to_i > 100 }
    end
  end

  def draw_monthly(pdf)
    rows = report.monthly_rows
    ensure_space(pdf, 140)
    section_title(pdf, "Month by month")
    data = [ [ "Month", "Income", "Expenses", "Net", "Balance at month end" ] ]
    rows.each { |month, income, expense, net, balance| data << [ month, money(income), money(expense), signed(net), money(balance) ] }
    data << [ "Total", money(report.income), money(report.expense), signed(report.income - report.expense), money(report.closing_balance) ]
    table(pdf, data, money_columns: 1..4) do |t|
      t.column(3).rows(1..-2).each { |cell| cell.text_color = cell.content.start_with?("−") ? MONEY_OUT : SOFT }
    end
  end

  def draw_signatures(pdf)
    ensure_space(pdf, 110)
    pdf.move_down 12
    section_title(pdf, "Approved")
    width = (pdf.bounds.width - 40) / 3
    top = pdf.cursor - 34
    [ "Treasurer", "Chairman", "Date" ].each_with_index do |label, index|
      x = index * (width + 20)
      pdf.stroke_color SOFT
      pdf.line_width 0.5
      pdf.stroke_line [ x, top ], [ x + width, top ]
      pdf.text_box label, at: [ x, top - 6 ], width: width, size: 8, color: MUTED
    end
    pdf.move_cursor_to(top - 24)
  end

  def draw_page_furniture(pdf)
    pdf.repeat(:all) do
      pdf.bounding_box([ 0, -18 ], width: pdf.bounds.width, height: 20) do
        hairline(pdf)
        pdf.move_down 7
        pdf.text clean("Tokyo Mizo Church  ·  #{unit.name}  ·  Annual report #{report.label}"), size: 7, color: MUTED
      end
    end
    pdf.number_pages "Page <page> of <total>", at: [ pdf.bounds.width - 120, -25 ], width: 120, align: :right, size: 7, color: MUTED
  end

  # A report table with a bold total row; the block can style it further.
  def table(pdf, data, money_columns:)
    pdf.table(data, header: true, width: pdf.bounds.width, column_widths: { 0 => 170 }) do |t|
      style_table(t)
      t.columns(money_columns).align = :right
      t.row(-1).font_style = :bold
      t.row(-1).text_color = INK
      t.row(-1).borders = [ :top, :bottom ]
      t.row(-1).border_top_color = INK
      t.row(-1).border_top_width = 0.8
      t.rows(1..-2).each { |cell| cell.text_color = MUTED if cell.content == "¥0" }
      yield t if block_given?
    end
    pdf.move_down 24
  end

  # "↑12% vs 2024", or nil when there is nothing to compare with.
  def change(now, before)
    "#{percent(now, before)} vs #{report.previous_label}" if FinanceSummary.change_percent(now, before)
  end

  # "↑12%", or "—" when there is nothing to compare with.
  def percent(now, before)
    value = FinanceSummary.change_percent(now, before)
    return "—" if value.nil?

    "#{value.positive? ? '↑' : (value.negative? ? '↓' : '')}#{value.abs}%"
  end
end
