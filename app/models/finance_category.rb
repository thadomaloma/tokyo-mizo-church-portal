class FinanceCategory < ApplicationRecord
  audited

  has_many :finance_transactions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category_type, presence: true, inclusion: { in: %w[income expense] }

  scope :income, -> { where(category_type: "income") }
  scope :expense, -> { where(category_type: "expense") }
end
