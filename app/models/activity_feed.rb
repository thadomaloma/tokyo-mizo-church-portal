# The Activity page: who added, edited or deleted entries, closed or
# reopened a month, or changed a budget, in the given finance units. Built
# from the audit log, newest first. Many entries added together by one
# person (an import, say) become one event, and so does each budget save.
class ActivityFeed
  KINDS = { "added" => "Added", "edited" => "Edited", "deleted" => "Deleted", "months" => "Months closed or reopened",
            "budgets" => "Budgets" }.freeze
  GROUP_MIN = 10
  GROUP_WINDOW = 5.minutes

  Event = Struct.new(:kind, :audits, :finance_unit, keyword_init: true) do
    def audit = audits.first
    def user = audit.user
    def at = audit.created_at
    def group? = kind == :added && audits.size > 1
  end

  def initialize(finance_units:, user_id: nil, kind: nil)
    @finance_units = finance_units.to_a
    @user_id = user_id
    @kind = kind
  end

  def events
    @events ||= build_events(filtered(audits).includes(:user).reorder(created_at: :desc, id: :desc).to_a)
  end

  # People who appear in these units' activity, for the filter.
  def people
    User.where(id: audits.distinct.pluck(:user_id)).order(:name)
  end

  # The entry as this audit saw it: its values when added or deleted, or as
  # it is now for an edit.
  def as_recorded(audit)
    audit.action == "update" ? transaction(audit) : snapshot_from(audit.audited_changes)
  end

  # The entry as it is now, or as it was when deleted.
  def transaction(audit)
    snapshots[audit.auditable_id] || snapshot_from(audit.audited_changes)
  end

  def finance_period(audit)
    finance_periods[audit.auditable_id]
  end

  def budget(audit)
    budgets[audit.associated_id]
  end

  def budget_category_name(audit)
    finance_categories[budget_line_categories[audit.auditable_id]]&.name || "A category"
  end

  private

  attr_reader :finance_units

  def unit_ids = finance_units.map(&:id)

  def audits
    Audited::Audit
      .where(auditable_type: "FinanceTransaction", auditable_id: FinanceTransaction.where(finance_unit_id: unit_ids).select(:id))
      .or(Audited::Audit.where(auditable_type: "FinanceTransaction", auditable_id: deleted_transaction_ids))
      .or(Audited::Audit.where(auditable_type: "FinancePeriod", auditable_id: FinancePeriod.where(finance_unit_id: unit_ids).select(:id)))
      .or(Audited::Audit.where(auditable_type: "FinanceBudgetLine", associated_type: "FinanceBudget",
                               associated_id: FinanceBudget.where(finance_unit_id: unit_ids).select(:id)))
  end

  def filtered(scope)
    scope = scope.where(user_id: @user_id) if @user_id
    case @kind
    when "added" then scope.where(auditable_type: "FinanceTransaction", action: "create")
    when "edited" then scope.where(auditable_type: "FinanceTransaction", action: "update")
    when "deleted" then scope.where(auditable_type: "FinanceTransaction", action: "destroy")
    when "months" then scope.where(auditable_type: "FinancePeriod")
    when "budgets" then scope.where(auditable_type: "FinanceBudgetLine")
    else scope
    end
  end

  def build_events(list)
    events = []
    list.each do |audit|
      previous = events.last
      if previous && same_group?(previous, audit)
        previous.audits << audit
      else
        events << Event.new(kind: kind_of(audit), audits: [ audit ], finance_unit: unit_of(audit))
      end
    end

    events.flat_map { |event| event.kind == :added && event.audits.size < GROUP_MIN ? split(event) : [ event ] }
          .reject { |event| event.kind == :edited && visible_changes(event.audit).empty? }
  end

  def same_group?(event, audit)
    case event.kind
    when :budget
      audit.auditable_type == "FinanceBudgetLine" && audit.request_uuid == event.audit.request_uuid
    when :added
      kind_of(audit) == :added && audit.user_id == event.audit.user_id && unit_of(audit) == event.finance_unit &&
        event.audits.last.created_at - audit.created_at <= GROUP_WINDOW
    else
      false
    end
  end

  def split(event)
    event.audits.map { |audit| Event.new(kind: :added, audits: [ audit ], finance_unit: event.finance_unit) }
  end

  def kind_of(audit)
    case audit.auditable_type
    when "FinancePeriod" then :month
    when "FinanceBudgetLine" then :budget
    else { "create" => :added, "update" => :edited, "destroy" => :deleted }.fetch(audit.action)
    end
  end

  def unit_of(audit)
    case audit.auditable_type
    when "FinancePeriod" then finance_period(audit)&.finance_unit
    when "FinanceBudgetLine" then budget(audit)&.finance_unit
    else transaction(audit).finance_unit
    end
  end

  def visible_changes(audit)
    audit.audited_changes.except(*FinanceTransactionsHelper::AUDIT_IGNORED_ATTRIBUTES)
  end

  # Transactions that were deleted, read from their delete record.
  def deleted_transaction_ids
    @deleted_transaction_ids ||= deletions.select { |_, changes| changes["finance_unit_id"].in?(unit_ids) }.keys
  end

  def deletions
    @deletions ||= Audited::Audit.where(auditable_type: "FinanceTransaction", action: "destroy")
                                 .to_h { |audit| [ audit.auditable_id, audit.audited_changes ] }
  end

  def snapshots
    @snapshots ||= FinanceTransaction.where(finance_unit_id: unit_ids).includes(:finance_category, :finance_unit).index_by(&:id)
                                     .then { |existing| deleted_transaction_ids.to_h { |id| [ id, snapshot_from(deletions[id]) ] }.merge(existing) }
  end

  def snapshot_from(changes)
    attributes = changes.slice(*FinanceTransaction.column_names).except("id")
    FinanceTransaction.new(attributes).tap do |record|
      record.finance_unit = finance_units.find { |unit| unit.id == record.finance_unit_id } || record.finance_unit
      record.finance_category = finance_categories[record.finance_category_id] if record.finance_category_id
    end
  end

  def finance_categories
    @finance_categories ||= FinanceCategory.where(finance_unit_id: unit_ids).index_by(&:id)
  end

  def finance_periods
    @finance_periods ||= FinancePeriod.where(finance_unit_id: unit_ids).includes(:finance_unit).index_by(&:id)
  end

  def budgets
    @budgets ||= FinanceBudget.where(finance_unit_id: unit_ids).includes(:finance_unit).index_by(&:id)
  end

  # Category of each budget line, also for lines removed since.
  def budget_line_categories
    @budget_line_categories ||= Audited::Audit.where(auditable_type: "FinanceBudgetLine", associated_id: budgets.keys)
                                              .each_with_object({}) do |audit, map|
      category_id = Array(audit.audited_changes["finance_category_id"]).compact.last
      map[audit.auditable_id] ||= category_id if category_id
    end.merge(FinanceBudgetLine.where(finance_budget_id: budgets.keys).pluck(:id, :finance_category_id).to_h)
  end
end
