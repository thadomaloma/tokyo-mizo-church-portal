class FinanceBudgetLine < ApplicationRecord
  belongs_to :finance_budget, inverse_of: :lines
  belongs_to :finance_category

  validates :amount, numericality: { only_integer: true, greater_than: 0 }
  validates :finance_category_id, uniqueness: { scope: :finance_budget_id }
  validate :category_is_an_expense_of_the_same_unit

  private

  def category_is_an_expense_of_the_same_unit
    return if finance_category.blank? || finance_budget.blank?
    return if finance_category.category_type == "expense" &&
              finance_category.finance_unit_id == finance_budget.finance_unit_id

    errors.add(:finance_category, "must be an expense category of this finance unit")
  end
end
