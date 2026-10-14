# Planned vs. actual spending for one finance unit and year. "Spent" is the
# year-to-date expense total per category; categories with spending but no
# plan are reported separately so nothing silently disappears.
class BudgetProgress
  Line = Struct.new(:category, :planned, :spent, keyword_init: true) do
    def remaining
      planned - spent
    end

    def percent_used
      return 0 if planned.zero?

      ((spent * 100.0) / planned).round
    end

    def over?
      spent > planned
    end
  end

  attr_reader :finance_unit, :year, :budget

  def initialize(finance_unit, year)
    @finance_unit = finance_unit
    @year = year
    @budget = FinanceBudget.includes(lines: :finance_category).for(finance_unit, year)
  end

  def planned?
    budget.present? && budget.lines.any?
  end

  def lines
    @lines ||= (budget&.lines || [])
      .sort_by { |line| [ line.finance_category.position, line.finance_category.name ] }
      .map do |line|
        Line.new(category: line.finance_category, planned: line.amount, spent: spent_by_category.fetch(line.finance_category_id, 0))
      end
  end

  def unplanned_spending
    planned_ids = lines.map { |line| line.category.id }
    spent_by_category.except(*planned_ids).sum { |_, amount| amount }
  end

  def planned_total
    lines.sum(&:planned)
  end

  def spent_total
    spent_by_category.values.sum
  end

  def remaining_total
    planned_total - spent_total
  end

  def percent_used
    return 0 if planned_total.zero?

    ((spent_total * 100.0) / planned_total).round
  end

  # Share of the year that has passed, to judge whether spending is on pace.
  def year_elapsed_percent(today = Date.current)
    return 100 if year < today.year
    return 0 if year > today.year

    ((today.yday * 100.0) / Date.new(year, 12, 31).yday).round
  end

  def status(today = Date.current)
    return :over if spent_total > planned_total
    return :watch if percent_used > year_elapsed_percent(today) + 10

    :on_track
  end

  private

  def spent_by_category
    @spent_by_category ||= finance_unit.finance_transactions
                                       .expense
                                       .where(transaction_date: Date.new(year, 1, 1)..Date.new(year, 12, 31))
                                       .group(:finance_category_id)
                                       .sum(:amount)
  end
end
