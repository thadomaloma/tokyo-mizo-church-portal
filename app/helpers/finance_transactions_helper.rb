module FinanceTransactionsHelper
  AUDIT_IGNORED_ATTRIBUTES = %w[
    id created_at updated_at voucher_number voucher_year
    finance_unit_id recorded_by_id
  ].freeze

  AUDIT_ATTRIBUTE_LABELS = {
    "finance_category_id" => "Category",
    "transaction_type" => "Type",
    "transaction_date" => "Date",
    "payment_location" => "Account",
    "transfer_to_location" => "Transfer To"
  }.freeze

  def yen(amount)
    "¥#{number_with_delimiter(amount.to_i)}"
  end

  # :income, :expense or :transfer. Seen from one account (`location`), a
  # transfer reads as money in or out of that account.
  def transaction_tone(transaction, location: nil)
    return transaction.transaction_type.to_sym unless transaction.transfer? && location

    transaction.transfer_to_location == location ? :income : :expense
  end

  def signed_yen(transaction, location: nil)
    sign = { income: "+", expense: "−", transfer: "" }.fetch(transaction_tone(transaction, location: location))
    "#{sign}#{yen(transaction.amount)}"
  end

  def transaction_icon(transaction)
    return "arrows-right-left" if transaction.transfer?

    transaction.income? ? "arrow-trending-up" : "arrow-trending-down"
  end

  TONE_CLASSES = {
    income: { icon: "bg-emerald-50 text-emerald-600 ring-emerald-100", amount: "text-emerald-700" },
    expense: { icon: "bg-rose-50 text-rose-600 ring-rose-100", amount: "text-rose-700" },
    transfer: { icon: "bg-sky-50 text-sky-600 ring-sky-100", amount: "text-slate-700" }
  }.freeze

  def tone_classes(tone, part)
    TONE_CLASSES.fetch(tone).fetch(part)
  end

  def percent_change_badge(percent, good_when: :up)
    return if percent.nil?

    good = percent.zero? || (good_when == :up ? percent.positive? : percent.negative?)
    arrow = percent.positive? ? "↑" : (percent.negative? ? "↓" : "")
    classes = good ? "bg-emerald-50 text-emerald-700" : "bg-rose-50 text-rose-700"

    tag.span("#{arrow}#{percent.abs}%", class: "inline-flex rounded-full px-2 py-0.5 text-[11px] font-black #{classes}",
             title: "Thla kal ta nen khaikhin")
  end

  def audit_action_label(audit)
    case audit.action
    when "create" then "Created"
    when "destroy" then "Deleted"
    else "Updated"
    end
  end

  def audit_attribute_label(attribute)
    AUDIT_ATTRIBUTE_LABELS.fetch(attribute, attribute.humanize)
  end

  def audit_change_value(attribute, value)
    case attribute
    when "amount"
      "¥#{number_with_delimiter(value.to_i)}"
    when "finance_category_id"
      value.present? ? (FinanceCategory.find_by(id: value)&.name || "Category ##{value}") : "None"
    when "transaction_date"
      value.present? ? value.to_date.strftime("%b %d, %Y") : "—"
    when "payment_location", "transfer_to_location"
      value.present? ? value.to_s.titleize : "—"
    else
      value.presence || "—"
    end
  end
end
