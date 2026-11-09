# One finance unit's year for the church's year-end meeting: opening and
# closing balance, income and expenses by category against the budget and
# the year before, and the year month by month. For the current year it
# runs to today and compares with the same days of last year.
#
# Opening balances bring money forward, so they count towards the opening
# balance, never as income.
class AnnualReport
  Line = Struct.new(:name, :amount, :previous, :budget, keyword_init: true) do
    def budget_used = budget.to_i.positive? ? ((amount * 100.0) / budget).round : nil
  end

  attr_reader :finance_unit, :year, :end_date

  def initialize(finance_unit, year, today: Date.current)
    @finance_unit = finance_unit
    @year = year
    @end_date = [ Date.new(year, 12, 31), today ].min
    raise ArgumentError, "#{year} has not started yet" if end_date.year < year
  end

  def range = Date.new(year)..end_date
  def previous_range = Date.new(year - 1)..end_date.prev_year
  def partial? = end_date < Date.new(year, 12, 31)

  def label
    partial? ? "#{year} (to #{end_date.strftime('%-d %B')})" : year.to_s
  end

  def previous_label
    partial? ? "#{year - 1} (same days)" : (year - 1).to_s
  end

  def opening_balance
    @opening_balance ||= summary.balance_on(range.begin - 1) + opening_entries(range)
  end

  def income = @income ||= received(range).income.sum(:amount)
  def expense = @expense ||= received(range).expense.sum(:amount)
  def previous_income = @previous_income ||= received(previous_range).income.sum(:amount)
  def previous_expense = @previous_expense ||= received(previous_range).expense.sum(:amount)
  def closing_balance = opening_balance + income - expense

  # Whether there is anything from the year before to compare with.
  def previous? = previous_income.positive? || previous_expense.positive?

  def account_balances
    FinanceTransaction::LOCATIONS.to_h { |location| [ location, summary.account_balance(location, on: end_date) ] }
  end

  def income_lines = lines("income")
  def expense_lines = lines("expense")

  def budget_total
    budget&.lines&.sum(&:amount).to_i
  end

  # [month label, income, expense, net, balance at the end of the month]
  def monthly_rows
    running = opening_balance - opening_entries(range)
    rows = received(range).or(opening_scope(range)).reorder(nil)
                          .left_joins(:finance_category).pluck(:transaction_type, :transaction_date, :amount, "finance_categories.code")

    (1..end_date.month).map do |month|
      in_month = rows.select { |_, date, _, _| date.month == month }
      opening = in_month.sum { |_, _, amount, code| code == "opening_balance" ? amount : 0 }
      month_income = in_month.sum { |type, _, amount, code| type == "income" && code != "opening_balance" ? amount : 0 }
      month_expense = in_month.sum { |type, _, amount, _| type == "expense" ? amount : 0 }
      running += opening + month_income - month_expense
      [ Date::MONTHNAMES[month], month_income, month_expense, month_income - month_expense, running ]
    end
  end

  private

  def summary
    @summary ||= FinanceSummary.new(finance_unit)
  end

  def received(dates)
    finance_unit.finance_transactions.without_opening_balances.where(transaction_date: dates)
  end

  def opening_scope(dates)
    finance_unit.finance_transactions.income.where(transaction_date: dates)
                .where(finance_category_id: FinanceCategory.where(code: "opening_balance").select(:id))
  end

  def opening_entries(dates)
    opening_scope(dates).sum(:amount)
  end

  def budget
    @budget ||= FinanceBudget.includes(:lines).for(finance_unit, year)
  end

  def lines(type)
    now = category_totals(received(range).where(transaction_type: type))
    before = category_totals(received(previous_range).where(transaction_type: type))
    planned = type == "expense" && budget ? budget.lines.to_h { |line| [ line.finance_category_id, line.amount ] } : {}
    names = FinanceCategory.where(id: now.keys | before.keys | planned.keys).pluck(:id, :name).to_h

    (now.keys | before.keys | planned.keys).map do |id|
      Line.new(name: names.fetch(id, "No category"), amount: now.fetch(id, 0), previous: before.fetch(id, 0), budget: planned[id])
    end.sort_by { |line| [ -line.amount, -line.previous, line.name ] }
  end

  def category_totals(scope)
    scope.reorder(nil).group(:finance_category_id).sum(:amount)
  end
end
