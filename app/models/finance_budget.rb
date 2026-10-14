# A finance unit's yearly spending plan: one planned amount per expense
# category. Spending is always read live from FinanceTransaction.
class FinanceBudget < ApplicationRecord
  belongs_to :finance_unit
  has_many :lines, class_name: "FinanceBudgetLine", dependent: :destroy, inverse_of: :finance_budget

  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 2000, less_than_or_equal_to: 2200 },
                   uniqueness: { scope: :finance_unit_id }

  def self.for(finance_unit, year)
    find_by(finance_unit: finance_unit, year: year)
  end

  def planned_total
    lines.sum(&:amount)
  end
end
