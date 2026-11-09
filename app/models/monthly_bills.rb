require "digest"

# The regular monthly bills (rent, utilities, love gifts, ...) entered on one
# form, as SundayOffering does for the Sunday collection. A bill is an
# expense with the same category and note in at least two of the three
# months before `month`, about once a month (so weekly spending like food
# is left out). A bill paid in all three months starts with its latest
# amount; one paid in only two starts empty, and so does a bill already
# entered in `month`, so nothing is recorded by mistake or twice.
class MonthlyBills
  include ActiveModel::Model
  include ActiveModel::Attributes

  LOOKBACK_MONTHS = 3

  Bill = Struct.new(:key, :finance_category, :description, :payment_location, :amount, :last_date, :recorded_on, :every_month,
                    keyword_init: true) do
    def name = description.presence || finance_category.name
  end

  attribute :transaction_date, :date
  attr_accessor :finance_unit, :recorded_by
  attr_reader :entries

  validates :transaction_date, presence: true
  validate :date_is_in_the_month
  validate :entries_are_valid
  validate :month_is_open

  def initialize(attributes = {})
    @entries = {}
    super
  end

  def month
    @month ||= (transaction_date || Date.current).beginning_of_month
  end

  def month=(date)
    @month = date.beginning_of_month
    self.transaction_date ||= month == Date.current.beginning_of_month ? Date.current : month.end_of_month
  end

  # { key => { amount: "12,000", payment_location: "bank" } } from the form.
  def entries=(raw)
    @entries = raw.to_h.transform_keys(&:to_s).transform_values do |entry|
      entry = entry.to_h.transform_keys(&:to_s)
      { amount: YenAmounts.parse(0 => entry["amount"])[0], payment_location: entry["payment_location"].to_s }
    end
  end

  def bills
    @bills ||= find_bills
  end

  # What the form shows for a bill: the amount typed, or a suggestion.
  def amount_for(bill)
    return entries.dig(bill.key, :amount) if entries.key?(bill.key)

    bill.amount if bill.every_month && !bill.recorded_on
  end

  def payment_location_for(bill)
    entries.dig(bill.key, :payment_location).presence || bill.payment_location
  end

  def chosen
    bills.filter_map do |bill|
      amount = entries.dig(bill.key, :amount)
      [ bill, amount ] if amount.is_a?(Integer) && amount.positive?
    end
  end

  def total
    chosen.sum(&:last)
  end

  def save
    return false unless valid?

    FinanceTransaction.transaction do
      chosen.each do |bill, amount|
        finance_unit.finance_transactions.create!(
          transaction_type: "expense", finance_category: bill.finance_category, amount: amount,
          transaction_date: transaction_date, payment_location: payment_location_for(bill),
          description: bill.description, recorded_by: recorded_by
        )
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.add(:base, error.record.errors.full_messages.to_sentence)
    false
  end

  private

  def find_bills
    earlier = (month << LOOKBACK_MONTHS)...month
    expenses = finance_unit.finance_transactions.expense.includes(:finance_category)
                           .where(transaction_date: earlier.begin..month.end_of_month).to_a
    this_month, before = expenses.partition { |expense| expense.transaction_date >= month }

    before.group_by { |expense| key_for(expense) }.filter_map do |key, group|
      months = group.map { |expense| expense.transaction_date.beginning_of_month }.uniq.size
      next if months < 2 || group.size > months * 1.5

      latest = group.max_by { |expense| [ expense.transaction_date, expense.created_at ] }
      recorded = this_month.select { |expense| key_for(expense) == key }.min_by(&:transaction_date)
      Bill.new(key: key, finance_category: latest.finance_category, description: latest.description.to_s.squish.presence,
               payment_location: latest.payment_location, amount: latest.amount, last_date: latest.transaction_date,
               recorded_on: recorded&.transaction_date, every_month: months == LOOKBACK_MONTHS)
    end.sort_by { |bill| [ bill.finance_category.position.to_i, bill.name.downcase ] }
  end

  def key_for(expense)
    Digest::SHA1.hexdigest("#{expense.finance_category_id}|#{expense.description.to_s.squish.downcase}")[0, 12]
  end

  def date_is_in_the_month
    return if transaction_date.blank? || transaction_date.beginning_of_month == month

    errors.add(:transaction_date, "must be in #{month.strftime('%B %Y')}")
  end

  def entries_are_valid
    if entries.values.any? { |entry| entry[:amount] == :invalid }
      errors.add(:base, "Amounts must be whole numbers (yen).")
    elsif entries.values.any? { |entry| entry[:payment_location].present? && !entry[:payment_location].in?(FinanceTransaction::LOCATIONS) }
      errors.add(:base, "Choose Cash or the bank account for each bill.")
    elsif chosen.empty?
      errors.add(:base, "Enter an amount for at least one bill.")
    end
  end

  def month_is_open
    return unless transaction_date && FinancePeriod.closed_on?(finance_unit, transaction_date)

    errors.add(:base, "#{transaction_date.strftime("%B %Y")} is closed. Reopen it from the monthly report first.")
  end
end
