class FinanceReportPdf
  def initialize(transactions:, income:, expense:, balance:, period_label: "This Year", period_year: Date.current.year, start_month: 1, end_month: Date.current.month)
    @transactions = transactions
    @income = income
    @expense = expense
    @balance = balance
    @period_label = period_label
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

  attr_reader :transactions, :income, :expense, :balance, :period_label, :report_data

  def build_header(pdf)
    pdf.text "Tokyo Mizo Church",
             size: 20,
             style: :bold,
             align: :center

    pdf.move_down 4

    pdf.text "Finance Report - #{period_label}",
             size: 14,
             align: :center

    pdf.move_down 4

    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}",
             size: 10,
             align: :center

    pdf.move_down 16
    pdf.stroke_horizontal_rule
  end

  def build_summary_and_chart(pdf)
    pdf.move_down 20
    top = pdf.cursor
    summary_width = 230
    chart_gap = 24
    chart_width = pdf.bounds.width - summary_width - chart_gap
    summary_table = build_summary_table(pdf, summary_width)
    monthly_table = build_monthly_tithe_offering_table(pdf, chart_width)
    section_height = [
      summary_section_height(pdf, summary_width, summary_table),
      chart_section_height(pdf, chart_width, monthly_table)
    ].max.ceil

    pdf.bounding_box([ 0, top ], width: summary_width, height: section_height) do
      pdf.text "Summary", size: 13, style: :bold
      pdf.move_down 6

      summary_table.draw
    end

    pdf.bounding_box([ summary_width + chart_gap, top ], width: chart_width, height: section_height) do
      build_income_expense_chart(pdf, chart_width)
      build_compact_monthly_tithe_offering(pdf, monthly_table)
    end

    pdf.move_cursor_to(top - section_height)
  end

  def summary_section_height(pdf, width, table)
    pdf.height_of("Summary", size: 13, style: :bold, width: width) + 6 + table.height
  end

  def chart_section_height(pdf, width, monthly_table)
    pdf.height_of("Income vs Expense", size: 13, style: :bold, width: width) +
      10 +
      (report_data.chart_rows.size * 24) +
      2 +
      pdf.height_of("Monthly Tithe and Offering", size: 9, style: :bold, width: width) +
      4 +
      monthly_table.height
  end

  def build_income_expense_chart(pdf, width)
    pdf.text "Income vs Expense", size: 13, style: :bold
    pdf.move_down 10

    max_amount = report_data.chart_rows.map(&:last).max.to_f
    max_amount = 1 if max_amount.zero?
    label_width = 52
    amount_width = 76
    bar_width = width - label_width - amount_width - 12
    bar_height = 12

    report_data.chart_rows.each do |label, amount|
      pdf.fill_color "334155"
      pdf.text_box label,
                   at: [ 0, pdf.cursor ],
                   width: label_width,
                   height: 14,
                   size: 8,
                   style: :bold

      pdf.fill_color(label == "Income" ? "047857" : "BE123C")
      pdf.fill_rectangle [ label_width, pdf.cursor - 2 ],
                         [ (amount.to_f / max_amount) * bar_width, 2 ].max,
                         bar_height

      pdf.fill_color "334155"
      pdf.text_box yen(amount),
                   at: [ label_width + bar_width + 10, pdf.cursor ],
                   width: amount_width,
                   height: 14,
                   size: 8,
                   align: :right

      pdf.move_down 24
    end

    pdf.fill_color "000000"
  end

  def build_compact_monthly_tithe_offering(pdf, monthly_table)
    pdf.move_down 2
    pdf.text "Monthly Tithe and Offering", size: 9, style: :bold
    pdf.move_down 4

    monthly_table.draw
  end

  def build_transactions(pdf)
    pdf.move_down 14
    pdf.text "Transactions", size: 14, style: :bold
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
      row(0).background_color = "E2E8F0"

      cells.size = 8
      cells.padding = 4
      cells.border_color = "CBD5E1"

      columns(0).nowrap = true
      columns(1).nowrap = true

      columns(1).align = :center
      columns(3).align = :center
      columns(5).align = :right
    end
  end

  def summary_rows
    report_data.summary_rows.map { |label, amount| [ label, yen(amount) ] }
  end

  def build_summary_table(pdf, width)
    pdf.make_table(summary_rows, width: width) do
      cells.padding = 5
      cells.size = 8
      cells.border_color = "CBD5E1"

      row(2).font_style = :bold
      row(2).background_color = "DCFCE7"
      row(2).text_color = "166534"
      columns(1).align = :right
    end
  end

  def monthly_tithe_offering_rows
    rows = [ [ "Month", "Tithe", "Offering" ] ]
    report_data.monthly_tithe_offering_rows.each do |month, tithe, offering|
      rows << [ month, yen(tithe), yen(offering) ]
    end
    rows
  end

  def build_monthly_tithe_offering_table(pdf, width)
    pdf.make_table(monthly_tithe_offering_rows, header: true, width: width) do
      row(0).font_style = :bold
      row(0).background_color = "E2E8F0"

      cells.size = 6.5
      cells.padding = 3
      cells.border_color = "CBD5E1"
      columns(1..2).align = :right
    end
  end

  def transaction_rows
    rows = [
      [ "Date", "Type", "Category", "Location", "Description", "Amount" ]
    ]

    pdf_transactions.each do |transaction|
      rows << [
        transaction.transaction_date.strftime("%Y-%m-%d"),
        type_cell(transaction),
        transaction.finance_category&.name || "-",
        transaction.payment_location_bank? ? "Bank" : "Cash",
        transaction.description.presence || "-",
        yen(transaction.amount)
      ]
    end

    rows
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
