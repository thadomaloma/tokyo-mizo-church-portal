class FinanceCategory < ApplicationRecord
  audited

  has_many :finance_transactions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category_type, presence: true, inclusion: { in: %w[income expense] }

  scope :income, -> { where(category_type: "income") }
  scope :expense, -> { where(category_type: "expense") }
  scope :for_transaction_type, ->(transaction_type) {
    normalized_type = transaction_type.to_s

    normalized_type.in?(%w[income expense]) ? where(category_type: normalized_type) : none
  }
end
