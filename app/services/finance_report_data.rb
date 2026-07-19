class FinanceReportData
  TITHE_KEYWORDS = [
    "sawmapakhat",
    "sawm pakhat",
    "sawma pakhat",
    "tithe",
    "10%"
  ].freeze

  OFFERING_KEYWORDS = [
    "thawhlawm",
    "thawh hlawm",
    "offering",
    "weekly offering"
  ].freeze

  attr_reader :transactions, :income, :expense, :balance, :period_year, :start_month, :end_month

  def initialize(transactions:, income:, expense:, balance:, period_year:, start_month:, end_month:)
    @transactions = transactions
    @income = income
    @expense = expense
    @balance = balance
    @period_year = period_year
    @start_month = start_month
    @end_month = end_month
  end

  def summary_rows
    [
      [ "Total Income", income ],
      [ "Total Expense", expense ],
      [ "Balance", balance ],
      [ "Cash Balance", cash_balance ],
      [ "Bank Account Balance", bank_balance ]
    ]
  end

  def chart_rows
    [
      [ "Income", income ],
      [ "Expense", expense ]
    ]
  end

  def monthly_tithe_offering_rows
    month_dates.map do |date|
      month_transactions = income_transactions.select do |transaction|
        transaction.transaction_date&.year == date.year &&
          transaction.transaction_date&.month == date.month
      end

      [
        date.strftime("%b %Y"),
        category_total(month_transactions, TITHE_KEYWORDS),
        category_total(month_transactions, OFFERING_KEYWORDS)
      ]
    end
  end

  private

  def income_transactions
    transactions.select(&:income?)
  end

  def cash_balance
    transactions.select(&:payment_location_cash?).sum { |transaction| signed_amount(transaction) }
  end

  def bank_balance
    transactions.select(&:payment_location_bank?).sum { |transaction| signed_amount(transaction) }
  end

  def signed_amount(transaction)
    transaction.income? ? transaction.amount : -transaction.amount
  end

  def month_dates
    (start_month..end_month).map { |month| Date.new(period_year, month, 1) }
  end

  def category_total(month_transactions, keywords)
    month_transactions.sum do |transaction|
      category_name = normalized_category_name(transaction)
      keywords.any? { |keyword| category_name.include?(normalize_keyword(keyword)) } ? transaction.amount : 0
    end
  end

  def normalized_category_name(transaction)
    normalize_keyword(transaction.finance_category&.name)
  end

  def normalize_keyword(value)
    value.to_s.downcase.squish
  end
end
