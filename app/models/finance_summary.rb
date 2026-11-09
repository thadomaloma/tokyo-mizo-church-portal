# Centralizes the "at a glance" finance figures reused across the dashboard,
# accounts page and ledger, so every surface agrees on the same numbers.
#
# Transfers only move money between a unit's own Cash and Bank accounts:
# they shift the per-account balances but never count as income or expense.
class FinanceSummary
  def initialize(finance_unit, today: Date.current)
    @finance_unit = finance_unit
    @today = today
  end

  def current_balance
    @current_balance ||= transactions.income.sum(:amount) - transactions.expense.sum(:amount)
  end

  # Income − expense up to and including `date` (transfers move money between
  # accounts and never change the total).
  def balance_on(date)
    scope = transactions.where(transaction_date: ..date)
    scope.income.sum(:amount) - scope.expense.sum(:amount)
  end

  def cash_balance
    account_balance("cash")
  end

  def bank_balance
    account_balance("bank")
  end

  # Balance of one account (cash or bank), optionally as at the end of `on`.
  def account_balance(location, on: nil)
    @account_balances ||= {}
    @account_balances[[ location, on ]] ||= begin
      scope = on ? transactions.where(transaction_date: ..on) : transactions
      scope.income.where(payment_location: location).sum(:amount) -
        scope.expense.where(payment_location: location).sum(:amount) -
        scope.transfer.where(payment_location: location).sum(:amount) +
        scope.transfer.where(transfer_to_location: location).sum(:amount)
    end
  end

  # [money in, money out] for one account this month, transfers included.
  def account_month_flow(location)
    month = transactions.where(transaction_date: today.all_month)
    [
      month.income.where(payment_location: location).sum(:amount) + month.transfer.where(transfer_to_location: location).sum(:amount),
      month.expense.where(payment_location: location).sum(:amount) + month.transfer.where(payment_location: location).sum(:amount)
    ]
  end

  def month_income
    @month_income ||= month_total(:income, today)
  end

  def month_expense
    @month_expense ||= month_total(:expense, today)
  end

  def net_change
    month_income - month_expense
  end

  def previous_month_income
    @previous_month_income ||= month_total(:income, today.prev_month)
  end

  def previous_month_expense
    @previous_month_expense ||= month_total(:expense, today.prev_month)
  end

  # Percentage change against an earlier period, or nil when that period had
  # nothing to compare with.
  def self.change_percent(current, previous)
    return if previous.to_i.zero?

    (((current - previous) * 100.0) / previous).round
  end

  # Income and expense totals for the last `count` months, oldest first.
  def monthly_overview(count = 6)
    months = (0...count).map { |offset| today.beginning_of_month << (count - 1 - offset) }
    rows = transactions.without_opening_balances
                       .where(transaction_date: months.first..today.end_of_month)
                       .pluck(:transaction_type, :transaction_date, :amount)

    months.map do |month|
      in_month = rows.select { |_, date, _| date.beginning_of_month == month }

      {
        label: month.strftime("%b"),
        income: in_month.sum { |type, _, amount| type == "income" ? amount : 0 },
        expense: in_month.sum { |type, _, amount| type == "expense" ? amount : 0 }
      }
    end
  end

  # Running total of expenses by day: this month (up to today) against the
  # whole of last month, so the reader sees whether spending is ahead of pace.
  def spending_pace
    this_start = today.beginning_of_month
    last_start = this_start.prev_month
    rows = transactions.expense.where(transaction_date: last_start..today.end_of_month)
                       .group(:transaction_date).sum(:amount)
    days = (1..[ this_start.end_of_month.day, last_start.end_of_month.day ].max).to_a

    cumulative = lambda do |start, last_day|
      running = 0
      days.map do |day|
        next nil if day > last_day

        running += rows.fetch(start + (day - 1), 0)
      end
    end

    {
      days: days,
      this_month: cumulative.call(this_start, today.day),
      last_month: cumulative.call(last_start, last_start.end_of_month.day),
      this_label: this_start.strftime("%B"),
      last_label: last_start.strftime("%B")
    }
  end

  # Total balance (income − expense) at the end of each of the last `count`
  # months; the current month matches `current_balance`, so entries dated
  # after today count too.
  def balance_history(count = 12)
    months = (0...count).map { |offset| today.beginning_of_month << (count - 1 - offset) }
    opening = transactions.income.where(transaction_date: ...months.first).sum(:amount) -
              transactions.expense.where(transaction_date: ...months.first).sum(:amount)
    movements = transactions.income_or_expense.where(transaction_date: months.first..)
                            .pluck(:transaction_type, :transaction_date, :amount)

    running = opening
    months.map do |month|
      in_month = movements.select { |_, date, _| month == months.last ? date >= month : date.beginning_of_month == month }
      running += in_month.sum { |type, _, amount| type == "income" ? amount : -amount }
      { label: month.strftime("%b"), balance: running }
    end
  end

  # This year so far against the same days of last year: income, expenses
  # and giving (tithe + offering), plus income by month for both years.
  def year_comparison
    this_year = today.beginning_of_year..today
    last_year = this_year.begin.prev_year..today.prev_year
    rows = transactions.without_opening_balances.left_joins(:finance_category)
                       .where(transaction_date: last_year.begin..today.end_of_year)
                       .pluck(:transaction_type, :transaction_date, :amount, "finance_categories.code", "finance_categories.name")
                       .map { |type, date, amount, code, name| [ type, date, amount, FinanceReportData.giving_kind(code, name) ] }

    totals = lambda do |range|
      in_range = rows.select { |_, date, _, _| range.cover?(date) }
      {
        income: in_range.sum { |type, _, amount, _| type == "income" ? amount : 0 },
        expense: in_range.sum { |type, _, amount, _| type == "expense" ? amount : 0 },
        giving: in_range.sum { |type, _, amount, giving| type == "income" && giving ? amount : 0 }
      }
    end
    monthly_income = lambda do |year, last_month|
      (1..12).map do |month|
        next if month > last_month

        rows.sum { |type, date, amount, _| type == "income" && date.year == year && date.month == month ? amount : 0 }
      end
    end

    {
      year: today.year,
      previous_year: today.year - 1,
      current: totals.call(this_year),
      previous: totals.call(last_year),
      months: (1..12).map { |month| Date::ABBR_MONTHNAMES[month] },
      income_by_month: monthly_income.call(today.year, today.month),
      previous_income_by_month: monthly_income.call(today.year - 1, 12)
    }
  end

  private

  attr_reader :finance_unit, :today

  def month_total(type, date)
    transactions.without_opening_balances.public_send(type)
                .where(transaction_date: date.beginning_of_month..date.end_of_month)
                .sum(:amount)
  end

  def transactions
    finance_unit.finance_transactions
  end
end
