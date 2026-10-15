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

  # Replaces the plan with `amounts` ({ category_id => yen }). Categories
  # left blank drop out of the budget. Returns false (with errors) when an
  # amount is not a whole number or a line fails validation.
  def update_amounts(amounts, categories)
    if YenAmounts.invalid?(amounts)
      errors.add(:base, "Amounts must be whole numbers (yen).")
      return false
    end

    transaction do
      save!
      categories.each do |category|
        line = lines.find_or_initialize_by(finance_category: category)
        amount = amounts[category.id].to_i

        if amount.positive?
          line.update!(amount: amount)
        elsif line.persisted?
          line.destroy!
        end
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.add(:base, error.record.errors.full_messages.to_sentence)
    false
  end
end
