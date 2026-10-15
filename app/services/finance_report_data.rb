class FinanceReportData
  TITHE_KEYWORDS = [
    "sawmapakhat",
    "sawm pakhat",
    "sawm a pakhat",
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

  # `account_balances` are the real Cash and Bank balances at the end of the
  # period ({ "cash" => n, "bank" => n }), transfers included. Without them
  # the report falls back to the period's income − expense per account.
  def initialize(transactions:, income:, expense:, balance:, period_year:, start_month:, end_month:, account_balances: nil)
    @transactions = transactions
    @income = income
    @expense = expense
    @balance = balance
    @period_year = period_year
    @start_month = start_month
    @end_month = end_month
    @account_balances = account_balances
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

  def closing_cash
    cash_balance
  end

  def closing_bank
    bank_balance
  end

  def closing_balances?
    @account_balances.present?
  end

  # [[category name, amount], ...] largest first.
  def income_by_category
    category_totals(transactions.select(&:income?))
  end

  def expense_by_category
    category_totals(transactions.select(&:expense?))
  end

  # [[month label, income, expense, net, tithe, offering], ...]
  def monthly_rows
    month_dates.map do |date|
      in_month = transactions.select { |transaction| transaction.transaction_date&.year == date.year && transaction.transaction_date&.month == date.month }
      income_total = in_month.select(&:income?).sum(&:amount)
      expense_total = in_month.select(&:expense?).sum(&:amount)
      incomes = in_month.select(&:income?)

      [
        date.strftime("%b %Y"),
        income_total,
        expense_total,
        income_total - expense_total,
        category_total(incomes, TITHE_KEYWORDS),
        category_total(incomes, OFFERING_KEYWORDS)
      ]
    end
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
    return @account_balances.fetch("cash", 0) if closing_balances?

    transactions.select(&:payment_location_cash?).sum { |transaction| signed_amount(transaction) }
  end

  def bank_balance
    return @account_balances.fetch("bank", 0) if closing_balances?

    transactions.select(&:payment_location_bank?).sum { |transaction| signed_amount(transaction) }
  end

  def category_totals(list)
    list.group_by { |transaction| transaction.finance_category&.name || "Uncategorised" }
        .map { |name, items| [ name, items.sum(&:amount) ] }
        .sort_by { |_, amount| -amount }
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
      keywords.any? { |keyword| category_matches_keyword?(category_name, keyword) } ? transaction.amount : 0
    end
  end

  def category_matches_keyword?(category_name, keyword)
    normalized_keyword = normalize_keyword(keyword)

    category_name.include?(normalized_keyword) ||
      category_name.delete(" ").include?(normalized_keyword.delete(" "))
  end

  def normalized_category_name(transaction)
    normalize_keyword(transaction.finance_category&.name)
  end

  def normalize_keyword(value)
    value.to_s.downcase.squish
  end
end
