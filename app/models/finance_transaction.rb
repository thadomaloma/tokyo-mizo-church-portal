class FinanceTransaction < ApplicationRecord
  audited

  TYPES = %w[income expense transfer].freeze
  LOCATIONS = %w[cash bank].freeze
  LOCATION_LABELS = { "cash" => "Cash", "bank" => "Bank" }.freeze

  belongs_to :finance_category, optional: true
  belongs_to :finance_unit
  belongs_to :recorded_by, class_name: "User", inverse_of: :finance_transactions

  before_validation :assign_finance_unit_from_category
  before_validation :clear_voucher_number, unless: :expense?
  before_validation :clear_transfer_fields, if: :transfer?
  before_save :assign_voucher_number, if: :expense?

  enum :payment_location, {
    cash: "cash",
    bank: "bank"
  }, prefix: true

  normalizes :transfer_to_location, with: ->(value) { value.presence }

  validates :transaction_type, presence: true, inclusion: { in: TYPES }
  validates :amount, numericality: { greater_than: 0 }
  validates :transaction_date, presence: true
  validates :payment_location, presence: true
  validates :voucher_number,
            uniqueness: {
              scope: %i[finance_unit_id voucher_year],
              conditions: -> { where(transaction_type: "expense") },
              allow_nil: true
            }
  validates :finance_category, presence: true, unless: :transfer?
  validates :transfer_to_location, inclusion: { in: LOCATIONS }, if: :transfer?
  validates :transfer_to_location, absence: true, unless: :transfer?
  validate :finance_category_type_matches_transaction_type
  validate :transfer_moves_between_accounts, if: :transfer?

  scope :latest, -> { order(transaction_date: :desc, created_at: :desc) }
  scope :income, -> { where(transaction_type: "income") }
  scope :expense, -> { where(transaction_type: "expense") }
  scope :transfers, -> { where(transaction_type: "transfer") }
  scope :income_or_expense, -> { where(transaction_type: %w[income expense]) }
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
      .where(patterns.map { "finance_categories.name LIKE ?" }.join(" OR "), *patterns)
  end

  def income?
    transaction_type == "income"
  end

  def expense?
    transaction_type == "expense"
  end

  def transfer?
    transaction_type == "transfer"
  end

  def location_label
    LOCATION_LABELS.fetch(payment_location, payment_location.to_s.humanize)
  end

  def transfer_to_label
    LOCATION_LABELS.fetch(transfer_to_location, transfer_to_location.to_s.humanize)
  end

  # Shown wherever a category name would be: transfers have no category.
  def title
    return "#{location_label} → #{transfer_to_label}" if transfer?

    finance_category&.name || "No Category"
  end

  def expense_voucher_number
    return unless expense?
    return unless voucher_number.present? && voucher_year.present?

    "EXP-#{voucher_year}-#{voucher_number.to_i.to_s.rjust(4, "0")}"
  end

  private

  def clear_voucher_number
    self.voucher_number = nil
    self.voucher_year = nil
  end

  # Scoped to (finance_unit, year) via a dedicated FinanceVoucherSequence
  # row per pair, so numbering restarts at 1 each year without ever
  # reusing or renumbering a prior year's vouchers — a MAX(voucher_number)
  # query would let a deleted latest voucher's number be reissued, and a
  # single running counter column on finance_unit can't handle backdated/
  # out-of-order transaction_date values without colliding across years.
  # The sequence row itself is locked (SELECT ... FOR UPDATE) to make the
  # read-increment-write atomic under concurrent assignment.
  def assign_voucher_number
    return if voucher_number.present?
    return unless finance_unit

    year = transaction_date&.year || Date.current.year
    sequence = find_or_create_voucher_sequence(year)

    sequence.with_lock do
      sequence.next_number += 1
      sequence.save!
      self.voucher_number = sequence.next_number
      self.voucher_year = year
    end
  end

  def find_or_create_voucher_sequence(year)
    FinanceVoucherSequence.find_by(finance_unit: finance_unit, year: year) ||
      FinanceVoucherSequence.create!(finance_unit: finance_unit, year: year, next_number: 0)
  rescue ActiveRecord::RecordNotUnique
    FinanceVoucherSequence.find_by!(finance_unit: finance_unit, year: year)
  end

  def clear_transfer_fields
    self.finance_category = nil
  end

  def transfer_moves_between_accounts
    return if payment_location.blank? || transfer_to_location.blank?
    return unless payment_location == transfer_to_location

    errors.add(:transfer_to_location, "must be a different account")
  end

  def finance_category_type_matches_transaction_type
    return if finance_category.blank? || transaction_type.blank?
    category_matches = finance_category.category_type == transaction_type
    unit_matches = finance_category.finance_unit == finance_unit
    return if category_matches && unit_matches

    errors.add(:finance_category, "must match the transaction type and finance unit")
  end

  def assign_finance_unit_from_category
    self.finance_unit ||= finance_category&.finance_unit || FinanceUnit.main
  end
end
