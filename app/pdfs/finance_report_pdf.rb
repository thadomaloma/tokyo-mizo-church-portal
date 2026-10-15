# Finance report PDF in the same editorial style as the app: warm neutrals,
# hairline rules, Newsreader for headline figures and Inter for everything
# else. Colour only marks money in (green) and out (red); amounts also carry
# +/− signs so the report still reads correctly when printed in black & white.
class FinanceReportPdf
  INK = "23221E".freeze
  SOFT = "46443D".freeze
  MUTED = "7B766B".freeze
  LINE = "E6E2D8".freeze
  SUNKEN = "F7F5F0".freeze
  BRAND = "16305A".freeze
  MONEY_IN = "2F7552".freeze
  MONEY_OUT = "A8432F".freeze

  FONT_DIR = Rails.root.join("vendor/fonts")
  LOGO_PATH = Rails.root.join("vendor/images/pdf-logo.png")
  CATEGORY_LIMIT = 8

  def initialize(
    transactions:,
    income:,
    expense:,
    balance:,
    period_label: "This Year",
    period_year: Date.current.year,
    start_month: 1,
    end_month: Date.current.month,
    ledger_type_label: "All Transactions",
    finance_unit_label: "Main Church Finance",
    account_balances: nil
  )
    @transactions = transactions
    @income = income
    @expense = expense
    @balance = balance
    @period_label = period_label.to_s.sub(" - ", " – ")
    @period_end = Date.new(period_year, end_month, -1)
    @ledger_type_label = ledger_type_label
    @finance_unit_label = finance_unit_label
    @report_data = FinanceReportData.new(
      transactions: transactions,
      income: income,
      expense: expense,
      balance: balance,
      period_year: period_year,
      start_month: start_month,
      end_month: end_month,
      account_balances: account_balances
    )
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: [ 54, 48, 64, 48 ], info: document_info)
    register_fonts(pdf)

    draw_cover(pdf)
    draw_summary(pdf)
    draw_balances(pdf)
    draw_categories(pdf)
    draw_monthly(pdf)
    draw_transactions(pdf)
    draw_page_furniture(pdf)

    pdf.render
  end

  private

  attr_reader :transactions, :income, :expense, :balance, :period_label, :period_end,
              :report_data, :ledger_type_label, :finance_unit_label

  def document_info
    { Title: "Tokyo Mizo Church finance report — #{period_label}", Author: "Tokyo Mizo Church", Creator: "Tokyo Mizo Church Finance" }
  end

  # --- Fonts -------------------------------------------------------------

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

  # --- Sections ----------------------------------------------------------

  def draw_cover(pdf)
    top = pdf.cursor
    pdf.image LOGO_PATH.to_s, at: [ 0, top ], width: 30 if File.exist?(LOGO_PATH)

    pdf.bounding_box([ 40, top + 1 ], width: 260) do
      pdf.font("Newsreader") { pdf.text "Tokyo Mizo Church", size: 15, color: INK }
      pdf.text "FINANCE REPORT", size: 7, color: MUTED, character_spacing: 1.2
    end

    pdf.bounding_box([ pdf.bounds.width - 220, top ], width: 220) do
      pdf.text finance_unit_label, size: 9, color: INK, align: :right, style: :medium
      pdf.text "Generated #{Date.current.strftime('%-d %B %Y')}", size: 7.5, color: MUTED, align: :right
    end

    pdf.move_cursor_to(top - 44)
    hairline(pdf)
    pdf.move_down 26

    pdf.text ledger_type_label.upcase, size: 7.5, color: MUTED, character_spacing: 1.2
    pdf.move_down 4
    pdf.font("Newsreader") { pdf.text period_label, size: 30, color: INK, leading: 2 }
    pdf.move_down 22
  end

  def draw_summary(pdf)
    columns = [
      [ "Income", money(income, sign: :plus), MONEY_IN ],
      [ "Expenses", money(expense, sign: :minus), MONEY_OUT ],
      [ "Net", money(balance, sign: balance.negative? ? :minus : :plus), INK ]
    ]
    width = pdf.bounds.width / columns.size
    top = pdf.cursor
    height = 62

    hairline(pdf, color: INK, width: 0.8)
    columns.each_with_index do |(label, value, color), index|
      x = index * width
      pdf.bounding_box([ x + (index.zero? ? 0 : 14), top - 12 ], width: width - 14, height: height - 12) do
        pdf.text label, size: 8, color: MUTED
        pdf.move_down 6
        pdf.font("Newsreader") { pdf.text value, size: 21, color: color }
      end
      next if index.zero?

      pdf.stroke_color LINE
      pdf.line_width 0.5
      pdf.stroke_line [ x, top - 10 ], [ x, top - height + 6 ]
    end
    pdf.move_cursor_to(top - height)
    hairline(pdf)
    pdf.move_down 18
  end

  def draw_balances(pdf)
    title = report_data.closing_balances? ? "Balances at #{period_end.strftime('%-d %B %Y')}" : "Movement by account"
    items = [
      [ "Cash", report_data.closing_cash ],
      [ "Bank", report_data.closing_bank ],
      [ "Total", report_data.closing_cash + report_data.closing_bank ]
    ]
    height = 46
    top = pdf.cursor

    pdf.fill_color SUNKEN
    pdf.fill_rounded_rectangle [ 0, top ], pdf.bounds.width, height, 6
    pdf.fill_color INK

    pdf.bounding_box([ 14, top - 10 ], width: 160, height: height - 10) do
      pdf.text title, size: 8, color: MUTED
      pdf.move_down 3
      pdf.text "Cash and bank, transfers included", size: 7, color: MUTED
    end

    column = (pdf.bounds.width - 190) / items.size
    items.each_with_index do |(label, amount), index|
      pdf.bounding_box([ 190 + index * column, top - 10 ], width: column - 14, height: height - 10) do
        pdf.text label, size: 7.5, color: MUTED, align: :right
        pdf.move_down 2
        pdf.text money(amount), size: 11, color: amount.negative? ? MONEY_OUT : INK, align: :right, style: (label == "Total" ? :bold : :normal)
      end
    end

    pdf.move_cursor_to(top - height)
    pdf.move_down 26
  end

  def draw_categories(pdf)
    gap = 28
    width = (pdf.bounds.width - gap) / 2
    top = pdf.cursor
    left_bottom = category_column(pdf, [ 0, top ], width, "Where the money came from", report_data.income_by_category, income, MONEY_IN)
    right_bottom = category_column(pdf, [ width + gap, top ], width, "Where the money went", report_data.expense_by_category, expense, MONEY_OUT)
    pdf.move_cursor_to([ left_bottom, right_bottom ].min)
    pdf.move_down 26
  end

  # Returns the cursor position below the column.
  def category_column(pdf, at, width, title, rows, total, color)
    rows = collapse_categories(rows)

    pdf.bounding_box(at, width: width) do
      section_title(pdf, title)

      if rows.empty?
        pdf.text "No records in this period.", size: 8.5, color: MUTED
      else
        top_amount = rows.first.last.to_f
        rows.each do |name, amount|
          share = total.to_i.zero? ? 0 : ((amount * 100.0) / total).round
          row_top = pdf.cursor
          pdf.text_box name, at: [ 0, row_top ], width: width - 96, height: 11, size: 8.5, color: SOFT, overflow: :ellipses
          pdf.text_box "#{money(amount)}  ", at: [ width - 96, row_top ], width: 70, height: 11, size: 8.5, color: INK, align: :right
          pdf.text_box "#{share}%", at: [ width - 26, row_top ], width: 26, height: 11, size: 7.5, color: MUTED, align: :right
          pdf.move_down 13

          pdf.fill_color LINE
          pdf.fill_rounded_rectangle [ 0, pdf.cursor ], width, 2.2, 1.1
          pdf.fill_color color
          pdf.fill_rounded_rectangle [ 0, pdf.cursor ], [ (amount / top_amount) * width, 2.2 ].max, 2.2, 1.1
          pdf.fill_color INK
          pdf.move_down 9
        end
      end
    end

    pdf.cursor
  end

  def collapse_categories(rows)
    return rows if rows.size <= CATEGORY_LIMIT

    rows.first(CATEGORY_LIMIT - 1) + [ [ "Other", rows.drop(CATEGORY_LIMIT - 1).sum(&:last) ] ]
  end

  def draw_monthly(pdf)
    rows = report_data.monthly_rows
    return if rows.empty?

    ensure_space(pdf, 60 + rows.size * 18)
    section_title(pdf, "Month by month")

    data = [ [ "Month", "Income", "Expenses", "Net", "Tithe", "Offering" ] ]
    rows.each do |month, month_income, month_expense, net, tithe, offering|
      data << [ month, money(month_income), money(month_expense), signed(net), money(tithe), money(offering) ]
    end
    totals = rows.transpose
    net_total = totals[3].sum
    data << [ "Total", money(totals[1].sum), money(totals[2].sum), signed(net_total), money(totals[4].sum), money(totals[5].sum) ]

    pdf.table(data, header: true, width: pdf.bounds.width, column_widths: { 0 => 95 }) do |table|
      style_table(table)
      table.columns(1..5).align = :right
      table.row(-1).font_style = :bold
      table.row(-1).text_color = INK
      table.row(-1).borders = [ :top, :bottom ]
      table.row(-1).border_top_color = INK
      table.row(-1).border_top_width = 0.8
      table.row(-1).border_bottom_color = INK
      table.row(-1).border_bottom_width = 0.8
      net_column = table.column(3)
      net_column.rows(1..-2).each { |cell| cell.text_color = cell.content.start_with?("−") ? MONEY_OUT : SOFT }
      table.rows(1..-2).each { |cell| cell.text_color = MUTED if cell.content == "¥0" }
    end
    pdf.move_down 28
  end

  def draw_transactions(pdf)
    ensure_space(pdf, 140)
    top = pdf.cursor
    section_title(pdf, "Transactions")
    pdf.text_box "#{transactions.size} #{transactions.size == 1 ? 'record' : 'records'}",
                 at: [ pdf.bounds.width - 120, top ], width: 120, size: 8, color: MUTED, align: :right

    if transactions.empty?
      pdf.text "No transactions in this period.", size: 9, color: MUTED
      return
    end

    data = [ [ "Date", "Description", "Account", "Amount" ] ]
    sorted_transactions.each do |transaction|
      title = clean(transaction.description.presence || transaction.finance_category&.name || "—")
      category = clean(transaction.finance_category&.name.to_s)
      details = [ category, transaction.expense_voucher_number ].compact_blank.join("  ·  ")
      data << [
        transaction.transaction_date.strftime("%-d %b %Y"),
        { content: "#{escape(title)}#{details.present? ? "\n<font size='7'><color rgb='#{MUTED}'>#{escape(details)}</color></font>" : ''}", inline_format: true },
        transaction.payment_location_bank? ? "Bank" : "Cash",
        signed_transaction(transaction)
      ]
    end

    pdf.table(data, header: true, width: pdf.bounds.width, column_widths: { 0 => 72, 2 => 52, 3 => 84 }) do |table|
      style_table(table)
      table.column(3).align = :right
      table.column(0).rows(1..-1).text_color = MUTED
      table.column(3).rows(1..-1).each { |cell| cell.text_color = cell.content.start_with?("+") ? MONEY_IN : MONEY_OUT }
    end
  end

  def draw_page_furniture(pdf)
    footer = "Tokyo Mizo Church  ·  #{finance_unit_label}  ·  #{period_label}"

    pdf.repeat(:all) do
      pdf.bounding_box([ 0, -18 ], width: pdf.bounds.width, height: 20) do
        hairline(pdf)
        pdf.move_down 7
        pdf.text clean(footer), size: 7, color: MUTED
      end
    end

    pdf.number_pages "Page <page> of <total>", at: [ pdf.bounds.width - 120, -25 ], width: 120, align: :right, size: 7, color: MUTED
  end

  # --- Building blocks -----------------------------------------------------

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

  def sorted_transactions
    transactions.sort_by do |transaction|
      [ transaction.transaction_date, transaction.created_at || Time.zone.at(0), transaction.id || 0 ]
    end.reverse
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

  def signed_transaction(transaction)
    money(transaction.amount, sign: transaction.income? ? :plus : :minus)
  end

  def clean(text)
    text.to_s.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "")
  end

  def escape(text)
    ERB::Util.html_escape(text)
  end
end
