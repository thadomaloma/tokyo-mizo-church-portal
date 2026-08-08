class FinanceTransaction < ApplicationRecord
  belongs_to :finance_category
  belongs_to :recorded_by, class_name: "User", inverse_of: :finance_transactions

  before_validation :clear_voucher_number, if: :income?
  before_validation :assign_voucher_number, if: :expense?

  enum :payment_location, {
    cash: "cash",
    bank: "bank"
  }, prefix: true

  validates :transaction_type, presence: true, inclusion: { in: %w[income expense] }
  validates :amount, numericality: { greater_than: 0 }
  validates :transaction_date, presence: true
  validates :payment_location, presence: true
  validates :voucher_number,
            uniqueness: {
              conditions: -> { where(transaction_type: "expense") },
              allow_nil: true
            }
  validate :finance_category_type_matches_transaction_type

  scope :latest, -> { order(transaction_date: :desc, created_at: :desc) }
  scope :income, -> { where(transaction_type: "income") }
  scope :expense, -> { where(transaction_type: "expense") }
  scope :this_month, -> { where(transaction_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :cash_records, -> { where(payment_location: "cash") }
  scope :bank_records, -> { where(payment_location: "bank") }

  scope :this_year, -> {
    where(transaction_date: Date.current.beginning_of_year..Date.current.end_of_year)
  }

  scope :for_category, ->(category_name) {
    joins(:finance_category).where(finance_categories: { name: category_name })
  }

  def self.for_category_keywords(*keywords)
    patterns = keywords
      .flatten
      .compact
      .map { |keyword| keyword.to_s.strip }
      .reject(&:blank?)
      .map { |keyword| "%#{sanitize_sql_like(keyword)}%" }

    return none if patterns.blank?

    joins(:finance_category)
      .where(patterns.map { "finance_categories.name ILIKE ?" }.join(" OR "), *patterns)
  end

  def income?
    transaction_type == "income"
  end

  def expense?
    transaction_type == "expense"
  end

  def expense_voucher_number
    return unless expense?

    number = voucher_number.presence || 1

    "EXP-#{number.to_i.to_s.rjust(4, "0")}"
  end

  private

  def clear_voucher_number
    self.voucher_number = nil
  end

  def assign_voucher_number
    return if voucher_number.present?

    self.voucher_number = self.class.expense.maximum(:voucher_number).to_i + 1
  end

  def finance_category_type_matches_transaction_type
    return if finance_category.blank? || transaction_type.blank?
    return if finance_category.category_type == transaction_type

    errors.add(:finance_category, "must match the transaction type")
  end
end
