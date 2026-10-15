# A Sunday collection as counted after the service: one amount per income
# category (tithe, offering, thanksgiving, ...). Saving it records one
# income transaction per category that has an amount, all or nothing.
class SundayOffering
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :transaction_date, :date, default: -> { Date.current - Date.current.wday }
  attribute :payment_location, :string, default: "cash"
  attribute :counted_by, :string
  attribute :note, :string

  attr_accessor :finance_unit, :recorded_by
  attr_reader :amounts

  validates :transaction_date, presence: true
  validates :payment_location, inclusion: { in: FinanceTransaction::LOCATIONS }
  validate :amounts_are_whole_yen
  validate :month_is_open

  def initialize(attributes = {})
    @amounts = {}
    super
  end

  def amounts=(raw)
    @amounts = YenAmounts.parse(raw)
  end

  def categories
    @categories ||= finance_unit.finance_categories.system_defined.income
                                .where.not(code: "opening_balance").order(:position, :name)
  end

  def total
    amounts.values.grep(Integer).sum
  end

  def save
    return false unless valid?

    FinanceTransaction.transaction do
      categories.each do |category|
        amount = amounts[category.id]
        next unless amount.is_a?(Integer) && amount.positive?

        finance_unit.finance_transactions.create!(
          transaction_type: "income", finance_category: category, amount: amount,
          transaction_date: transaction_date, payment_location: payment_location,
          description: description, recorded_by: recorded_by
        )
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.add(:base, error.record.errors.full_messages.to_sentence)
    false
  end

  private

  def description
    [ "Sunday offering", ("Counted by: #{counted_by.squish}" if counted_by.present?), note.presence&.squish ].compact.join(" · ")
  end

  def amounts_are_whole_yen
    if YenAmounts.invalid?(amounts)
      errors.add(:base, "Amounts must be whole numbers (yen).")
    elsif total.zero?
      errors.add(:base, "Enter an amount for at least one category.")
    end
  end

  def month_is_open
    return unless FinancePeriod.closed_on?(finance_unit, transaction_date)

    errors.add(:base, "#{transaction_date.strftime("%B %Y")} is closed. Reopen it from the monthly report first.")
  end
end
