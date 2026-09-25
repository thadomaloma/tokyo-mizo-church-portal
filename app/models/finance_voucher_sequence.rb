# A persistent, per-(finance_unit, year) counter for expense voucher
# numbering. Kept as its own row (rather than a column on FinanceUnit) so
# each year gets an independent, monotonically increasing sequence that is
# never affected by transaction deletions and never disturbed by
# out-of-order/backdated transaction_date values.
class FinanceVoucherSequence < ApplicationRecord
  belongs_to :finance_unit

  validates :year, presence: true
  validates :year, uniqueness: { scope: :finance_unit_id }
  validates :next_number, numericality: { greater_than_or_equal_to: 0 }
end
