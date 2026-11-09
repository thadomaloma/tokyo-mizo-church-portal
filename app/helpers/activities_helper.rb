module ActivitiesHelper
  def activity_day_label(date)
    return "Today" if date == Date.current
    return "Yesterday" if date == Date.yesterday

    date.strftime("%-d %b %Y")
  end

  def activity_person(event)
    event.user&.name || "System"
  end

  def activity_entry_kind(transaction)
    { "income" => "an income", "expense" => "an expense", "transfer" => "a transfer" }.fetch(transaction.transaction_type, "an entry")
  end

  # "Amount: ¥5,000 → ¥6,000" lines for an edit.
  def activity_changes(audit, finance_unit)
    audit.audited_changes.except(*FinanceTransactionsHelper::AUDIT_IGNORED_ATTRIBUTES).map do |attribute, (before, after)|
      [ audit_attribute_label(attribute), audit_change_value(attribute, before, finance_unit: finance_unit),
        audit_change_value(attribute, after, finance_unit: finance_unit) ]
    end
  end

  # A month's audit: :closed or :open (enums are stored by name or number).
  def activity_month_status(audit)
    status = Array(audit.audited_changes["status"]).last
    FinancePeriod.statuses.key(status).presence&.to_sym || status.to_s.to_sym
  end

  ICONS = { added: [ "plus", "tone-in" ], edited: [ "pencil-square", "tone-move" ], deleted: [ "trash", "tone-out" ],
            budget: [ "chart-pie", "tone-move" ] }.freeze

  def activity_icon(event, month_status: nil)
    icon, tone = event.kind == :month ? [ (month_status == :closed ? "lock-closed" : "lock-open"), "tone-move" ] : ICONS.fetch(event.kind)
    tag.span(heroicon(icon, variant: :outline, options: { class: "h-5 w-5" }), class: "row-icon #{tone}", aria: { hidden: true })
  end
end
