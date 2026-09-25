module FinanceTransactionsHelper
  AUDIT_IGNORED_ATTRIBUTES = %w[
    id created_at updated_at voucher_number voucher_year
    finance_unit_id recorded_by_id
  ].freeze

  AUDIT_ATTRIBUTE_LABELS = {
    "finance_category_id" => "Category",
    "transaction_type" => "Type",
    "transaction_date" => "Date",
    "payment_location" => "Payment Location"
  }.freeze

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
    when "payment_location"
      value.to_s.titleize
    else
      value.presence || "—"
    end
  end
end
