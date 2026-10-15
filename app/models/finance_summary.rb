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
    rows = transactions.income_or_expense
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

  # Total balance (income − expense to date) at the end of each of the last
  # `count` months; the current month shows today's balance.
  def balance_history(count = 12)
    months = (0...count).map { |offset| today.beginning_of_month << (count - 1 - offset) }
    opening = transactions.income.where(transaction_date: ...months.first).sum(:amount) -
              transactions.expense.where(transaction_date: ...months.first).sum(:amount)
    movements = transactions.income_or_expense.where(transaction_date: months.first..today)
                            .pluck(:transaction_type, :transaction_date, :amount)

    running = opening
    months.map do |month|
      in_month = movements.select { |_, date, _| date.beginning_of_month == month }
      running += in_month.sum { |type, _, amount| type == "income" ? amount : -amount }
      { label: month.strftime("%b"), balance: running }
    end
  end

  private

  attr_reader :finance_unit, :today

  def month_total(type, date)
    transactions.public_send(type)
                .where(transaction_date: date.beginning_of_month..date.end_of_month)
                .sum(:amount)
  end

  def transactions
    finance_unit.finance_transactions
  end
end
