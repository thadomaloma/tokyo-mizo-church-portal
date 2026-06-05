class FinanceReportPdf
  def initialize(transactions:, income:, expense:, balance:)
    @transactions = transactions
    @income = income
    @expense = expense
    @balance = balance
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)

    build_header(pdf)
    build_summary(pdf)
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

  attr_reader :transactions, :income, :expense, :balance

  def build_header(pdf)
    pdf.text "Tokyo Mizo Church",
             size: 20,
             style: :bold,
             align: :center

    pdf.move_down 4

    pdf.text "Finance Report",
             size: 14,
             align: :center

    pdf.move_down 4

    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}",
             size: 10,
             align: :center

    pdf.move_down 16
    pdf.stroke_horizontal_rule
  end

  def build_summary(pdf)
    pdf.move_down 20
    pdf.text "Summary", size: 14, style: :bold
    pdf.move_down 8

    pdf.table(summary_rows, width: pdf.bounds.width) do
      cells.padding = 8
      cells.border_color = "CBD5E1"

      row(2).font_style = :bold
      row(2).background_color = "DCFCE7"
      row(2).text_color = "166534"
    end
  end

  def build_transactions(pdf)
    pdf.move_down 20
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

      cells.size = 7
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
    [
      [ "Total Income", yen(income) ],
      [ "Total Expense", yen(expense) ],
      [ "Balance", yen(balance) ],
      [ "Cash Balance", yen(cash_balance) ],
      [ "Bank Account Balance", yen(bank_balance) ]
    ]
  end

  def transaction_rows
    rows = [
      [ "Date", "Type", "Category", "Location", "Description", "Amount" ]
    ]

    transactions.each do |transaction|
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

  def type_cell(transaction)
    if transaction.income?
      { content: "Income", text_color: "047857" }
    else
      { content: "Expense", text_color: "BE123C" }
    end
  end

  def cash_balance
    transactions.select(&:payment_location_cash?).sum do |transaction|
      signed_amount(transaction)
    end
  end

  def bank_balance
    transactions.select(&:payment_location_bank?).sum do |transaction|
      signed_amount(transaction)
    end
  end

  def signed_amount(transaction)
    transaction.income? ? transaction.amount : -transaction.amount
  end

  def yen(amount)
    "JPY #{amount.to_i.to_fs(:delimited)}"
  end
end
