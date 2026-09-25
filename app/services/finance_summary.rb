# Centralizes the small set of "at a glance" finance figures reused across
# the dashboard and the Finance Transactions ledger, so both surfaces stay
# in agreement instead of recomputing the same aggregates independently.
class FinanceSummary
  def initialize(finance_unit)
    @finance_unit = finance_unit
  end

  def current_balance
    @current_balance ||= transactions.income.sum(:amount) - transactions.expense.sum(:amount)
  end

  def month_income
    @month_income ||= transactions.income.this_month.sum(:amount)
  end

  def month_expense
    @month_expense ||= transactions.expense.this_month.sum(:amount)
  end

  def net_change
    month_income - month_expense
  end

  private

  attr_reader :finance_unit

  def transactions
    finance_unit.finance_transactions
  end
end
