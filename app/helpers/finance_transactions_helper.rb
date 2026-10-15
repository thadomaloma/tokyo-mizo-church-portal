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

  SMALL_NUMBERS = %w[zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen
                     fifteen sixteen seventeen eighteen nineteen].freeze
  TENS = %w[_ _ twenty thirty forty fifty sixty seventy eighty ninety].freeze
  SCALES = [ [ 1_000_000_000, "billion" ], [ 1_000_000, "million" ], [ 1_000, "thousand" ], [ 100, "hundred" ] ].freeze

  # Amount written out, as on a cheque or payment voucher:
  # 12_500 => "Twelve thousand five hundred yen only".
  def yen_in_words(amount)
    "#{number_in_words(amount.to_i.abs).capitalize} yen only"
  end

  def number_in_words(number)
    return SMALL_NUMBERS[number] if number < 20
    return [ TENS[number / 10], (SMALL_NUMBERS[number % 10] unless (number % 10).zero?) ].compact.join("-") if number < 100

    scale, name = SCALES.find { |value, _| number >= value }
    rest = number % scale
    [ "#{number_in_words(number / scale)} #{name}", (number_in_words(rest) unless rest.zero?) ].compact.join(" ")
  end

  def yen(amount)
    "¥#{number_with_delimiter(amount.to_i)}"
  end

  # Display amount: the currency symbol is set lighter than the figure.
  # `sign:` is :plus, :minus or :auto (minus only when negative).
  def money(amount, sign: :auto, class: nil)
    amount = amount.to_i
    prefix = case sign
    when :plus then "+"
    when :minus then "−"
    else amount.negative? ? "−" : ""
    end

    tag.span(class: [ "money", binding.local_variable_get(:class) ]) do
      safe_join([ prefix, tag.span("¥", class: "cur"), number_with_delimiter(amount.abs) ])
    end
  end

  def transaction_money(transaction, location: nil, class: nil)
    sign = { income: :plus, expense: :minus, transfer: nil }.fetch(transaction_tone(transaction, location: location))
    money(transaction.amount, sign: sign, class: [ tone_classes(transaction_tone(transaction, location: location), :amount), binding.local_variable_get(:class) ])
  end

  # :income, :expense or :transfer. Seen from one account (`location`), a
  # transfer reads as money in or out of that account.
  def transaction_tone(transaction, location: nil)
    return transaction.transaction_type.to_sym unless transaction.transfer? && location

    transaction.transfer_to_location == location ? :income : :expense
  end


  def transaction_icon(transaction)
    return "arrows-right-left" if transaction.transfer?

    transaction.income? ? "arrow-trending-up" : "arrow-trending-down"
  end

  TONE_CLASSES = {
    income: { icon: "tone-in", amount: "money-in" },
    expense: { icon: "tone-out", amount: "money-out" },
    transfer: { icon: "tone-move", amount: "money-move" }
  }.freeze

  def tone_classes(tone, part)
    TONE_CLASSES.fetch(tone).fetch(part)
  end

  # "↑12%" style chip; green when the change is good news, red otherwise.
  # The arrow keeps the meaning readable without relying on colour.
  def percent_change_badge(percent, good_when: :up)
    return if percent.nil?

    good = percent.zero? || (good_when == :up ? percent.positive? : percent.negative?)
    arrow = percent.positive? ? "↑" : (percent.negative? ? "↓" : "")

    tag.span("#{arrow}#{percent.abs}%", class: "chip #{good ? "chip-in" : "chip-out"}",
             title: "Compared with last month")
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
