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

  def cash_balance
    account_balance("cash")
  end

  def bank_balance
    account_balance("bank")
  end

  def account_balance(location)
    @account_balances ||= {}
    @account_balances[location] ||=
      transactions.income.where(payment_location: location).sum(:amount) -
      transactions.expense.where(payment_location: location).sum(:amount) -
      transactions.transfers.where(payment_location: location).sum(:amount) +
      transactions.transfers.where(transfer_to_location: location).sum(:amount)
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
