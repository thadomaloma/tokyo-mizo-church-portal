class FinanceReportData
  # Tithe and offering are recognised by their fixed category code. Older
  # categories without a code fall back to these name keywords.
  GIVING_CODES = %w[tithe offering].freeze

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
        giving_total(incomes, "tithe"),
        giving_total(incomes, "offering")
      ]
    end
  end

  def monthly_tithe_offering_rows
    month_dates.map do |date|
      month_transactions = income_transactions.select do |transaction|
        transaction.transaction_date&.year == date.year &&
          transaction.transaction_date&.month == date.month
      end

      [
        date.strftime("%b %Y"),
        giving_total(month_transactions, "tithe"),
        giving_total(month_transactions, "offering")
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

  def giving_total(list, kind)
    list.sum { |transaction| giving_kind(transaction.finance_category) == kind ? transaction.amount : 0 }
  end

  def giving_kind(category)
    return if category.nil?
    return category.code if category.code.in?(GIVING_CODES)
    return if category.code.present?

    name = normalize_keyword(category.name)
    return "tithe" if keyword_match?(name, TITHE_KEYWORDS)

    "offering" if keyword_match?(name, OFFERING_KEYWORDS)
  end

  def keyword_match?(name, keywords)
    keywords.any? do |keyword|
      keyword = normalize_keyword(keyword)
      name.include?(keyword) || name.delete(" ").include?(keyword.delete(" "))
    end
  end

  def normalize_keyword(value)
    value.to_s.downcase.squish
  end
end
