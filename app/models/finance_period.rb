# Minimal monthly-closing discipline for a finance unit. Deliberately not a
# full accounting-period system: opening/closing balances are always
# derived live from FinanceTransaction (no snapshot columns), and a month
# with no row here is simply "open" by default — a row only needs to exist
# once someone actually closes that month.
class FinancePeriod < ApplicationRecord
  belongs_to :finance_unit
  belongs_to :closed_by, class_name: "User", optional: true
  belongs_to :reopened_by, class_name: "User", optional: true

  enum :status, { open: 0, closed: 1 }

  validates :year, :month, presence: true
  validates :month, inclusion: { in: 1..12 }
  validates :year, uniqueness: { scope: %i[finance_unit_id month] }

  def self.closed_on?(finance_unit, date)
    date.present? && closed.exists?(finance_unit: finance_unit, year: date.year, month: date.month)
  end

  def self.find_or_open(finance_unit, year, month)
    find_by(finance_unit: finance_unit, year: year, month: month) ||
      new(finance_unit: finance_unit, year: year, month: month, status: :open)
  end

  def start_date = Date.new(year, month, 1)
  def end_date = start_date.end_of_month
  def label = start_date.strftime("%B %Y")

  def transactions
    finance_unit.finance_transactions.where(transaction_date: start_date..end_date)
  end

  # Checkable data problems that must be fixed before the month is locked.
  # Model validations normally prevent them; this is a safety net.
  def closing_issues
    missing_vouchers = transactions.expense.where(voucher_number: nil).count
    missing_vouchers.positive? ? [ "#{missing_vouchers} expense transaction(s) have no voucher number." ] : []
  end

  def close!(user)
    update!(status: :closed, closed_at: Time.current, closed_by: user)
  end

  def reopen!(user)
    update!(status: :open, reopened_at: Time.current, reopened_by: user)
  end
end
