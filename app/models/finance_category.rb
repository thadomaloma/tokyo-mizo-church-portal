class FinanceCategory < ApplicationRecord
  audited

  has_many :finance_transactions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category_type, presence: true, inclusion: { in: %w[income expense] }
  validate :category_type_cannot_change_when_used, on: :update

  scope :income, -> { where(category_type: "income") }
  scope :expense, -> { where(category_type: "expense") }
  scope :for_transaction_type, ->(transaction_type) {
    normalized_type = transaction_type.to_s

    normalized_type.in?(%w[income expense]) ? where(category_type: normalized_type) : none
  }

  private

  def category_type_cannot_change_when_used
    return unless will_save_change_to_category_type?
    return unless finance_transactions.exists?

    errors.add(:category_type, "cannot be changed after finance entries use this category")
  end
end
