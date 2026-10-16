# Moves the finance data from the old PostgreSQL database (Railway) into the
# app's SQLite database, then proves the copy is exact.
#
# The copy is 1:1: every row keeps its id and every shared column its value;
# validations and callbacks are skipped so nothing is recalculated. The only
# intended differences are in who can sign in:
#   - only the accounts in USER_EMAILS are carried over (renamed where the
#     new email differs; password hashes are copied unchanged), together
#     with their finance-unit memberships;
#   - users.role: retired church titles become Finance Secretary
#     (titles grant no access; see ReduceUserRoles).
# Import refuses to run if a dropped account recorded anything.
class PostgresMigration
  # Parents first, so foreign keys always point at rows already copied.
  TABLES = %w[
    users
    finance_units
    finance_unit_memberships
    finance_categories
    finance_voucher_sequences
    finance_periods
    finance_transactions
    audits
  ].freeze
  # Railway email => email in the new app. Everyone else is left behind.
  USER_EMAILS = {
    "president@example.com" => "chairman@example.com",
    "treasurer@example.com" => "treasurer@example.com"
  }.freeze
  # Columns that point at users; a dropped account must not appear in them.
  USER_REFERENCES = {
    "finance_transactions" => %w[recorded_by_id],
    "finance_periods" => %w[closed_by_id reopened_by_id],
    "audits" => %w[user_id]
  }.freeze
  KEPT_ROLES = [ 0, 2, 4, 5 ].freeze
  FALLBACK_ROLE = 5
  SAMPLE_LIMIT = 10

  class SourceRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  def initialize(source_url, out: $stdout)
    @out = out
    SourceRecord.establish_connection(source_url)
  end

  def import!(force: false)
    filled = TABLES.select { |table| target_model(table).exists? }
    if filled.any? && !force
      raise "Target already has data in: #{filled.join(', ')}. Use a fresh database (db:schema:load) or FORCE=1."
    end

    ensure_dropped_users_recorded_nothing!

    ActiveRecord::Base.transaction do
      TABLES.reverse_each { |table| target_model(table).delete_all } if filled.any?
      TABLES.each { |table| copy_table(table) }
    end
  end

  # Returns a list of problems; empty means the copy is exact.
  def verify
    problems = TABLES.flat_map { |table| verify_table(table) }
    print_finance_summary
    problems
  end

  def close
    SourceRecord.remove_connection
  end

  private

  attr_reader :out

  def copy_table(table)
    columns = shared_columns(table)
    copied = 0

    source_model(table).in_batches(of: 500) do |batch|
      rows = batch.pluck(*columns).filter_map { |values| transform(table, columns.zip(values).to_h) }
      target_model(table).insert_all!(rows, record_timestamps: false) if rows.any?
      copied += rows.size
    end

    expected = expected_rows(table)
    raise "#{table}: copied #{copied} of #{expected} rows" unless copied == expected

    skipped = source_model(table).count - copied
    out.puts format("%-26s %6d rows copied%s", table, copied, skipped.positive? ? " (#{skipped} left behind)" : "")
  end

  def expected_rows(table)
    columns = shared_columns(table)
    source_model(table).pluck(*columns).count { |values| transform(table, columns.zip(values).to_h) }
  end

  def kept_user_ids
    @kept_user_ids ||= source_model("users").where(email: USER_EMAILS.keys).pluck(:id)
  end

  def ensure_dropped_users_recorded_nothing!
    missing = USER_EMAILS.keys - source_model("users").where(email: USER_EMAILS.keys).pluck(:email)
    raise "Accounts to keep not found in PostgreSQL: #{missing.join(', ')}" if missing.any?

    USER_REFERENCES.each do |table, columns|
      columns.each do |column|
        orphaned = source_model(table).where.not(column => nil).where.not(column => kept_user_ids)
        orphaned = orphaned.where(user_type: [ nil, "User" ]) if table == "audits"
        next unless orphaned.exists?

        raise "#{table}.#{column} refers to accounts that would be left behind: #{orphaned.distinct.pluck(column).sort.join(', ')}"
      end
    end
  end

  def verify_table(table)
    columns = shared_columns(table)
    source_rows = source_model(table).order(:id).pluck(*columns)
                                     .filter_map { |values| transform(table, columns.zip(values).to_h) }
                                     .map { |row| normalize_row(row) }
    target_rows = target_model(table).order(:id).pluck(*columns).map { |values| normalize_row(columns.zip(values).to_h) }

    problems = []
    if source_rows.size != target_rows.size
      problems << "#{table}: #{source_rows.size} rows in PostgreSQL but #{target_rows.size} in SQLite"
    end

    mismatches = source_rows.zip(target_rows).reject { |source, target| source == target }
    mismatches.first(SAMPLE_LIMIT).each do |source, target|
      changed = source.keys.reject { |key| source[key] == target&.dig(key) }
      problems << "#{table} id #{source['id']}: #{changed.map { |key| "#{key} #{source[key].inspect} ≠ #{target&.dig(key).inspect}" }.join(', ')}"
    end
    problems << "#{table}: #{mismatches.size - SAMPLE_LIMIT} more mismatched rows" if mismatches.size > SAMPLE_LIMIT

    (target_model(table).column_names - columns).each do |column|
      next unless target_model(table).where.not(column => nil).exists?

      problems << "#{table}.#{column}: new column should be empty for copied rows"
    end

    out.puts format("%-26s %6d rows  %s", table, target_rows.size, problems.empty? ? "identical" : "DIFFERENT")
    problems
  end

  # Per-unit totals computed independently on both databases, so the
  # figures the treasurer knows can be checked by eye as well.
  def print_finance_summary
    out.puts
    out.puts format("%-24s %6s %14s %14s %14s %14s %14s", "Finance unit", "Rows", "Income", "Expense", "Balance", "Cash", "Bank")
    unit_names = target_model("finance_units").order(:position, :id).pluck(:id, :name)

    unit_names.each do |unit_id, name|
      totals = %i[source target].map { |side| unit_totals(side, unit_id) }
      flag = totals.uniq.size == 1 ? "" : "   <-- PostgreSQL #{totals.first.inspect}"
      income, expense, count, cash, bank = totals.last
      out.puts format("%-24s %6d %14s %14s %14s %14s %14s%s", name.first(24), count, yen(income), yen(expense), yen(income - expense), yen(cash), yen(bank), flag)
    end
  end

  def unit_totals(side, unit_id)
    model = side == :source ? source_model("finance_transactions") : target_model("finance_transactions")
    scope = model.where(finance_unit_id: unit_id)
    income = scope.where(transaction_type: "income").sum(:amount)
    expense = scope.where(transaction_type: "expense").sum(:amount)
    cash = %w[cash bank].map do |location|
      scope.where(transaction_type: "income", payment_location: location).sum(:amount) -
        scope.where(transaction_type: "expense", payment_location: location).sum(:amount)
    end
    [ income, expense, scope.count, *cash ]
  end

  # The row as it should exist in SQLite, or nil when it is left behind.
  def transform(table, row)
    case table
    when "users"
      return unless USER_EMAILS.key?(row["email"])

      row["email"] = USER_EMAILS.fetch(row["email"])
      row["role"] = FALLBACK_ROLE unless KEPT_ROLES.include?(row["role"])
    when "finance_unit_memberships"
      return unless kept_user_ids.include?(row["user_id"])
    end
    row
  end

  def normalize_row(row)
    row.transform_values do |value|
      case value
      when Time, ActiveSupport::TimeWithZone, DateTime then value.utc.iso8601(6)
      when Date then value.iso8601
      when BigDecimal then value.to_s("F")
      else value
      end
    end
  end

  def shared_columns(table)
    source_model(table).column_names & target_model(table).column_names
  end

  def source_model(table)
    @source_models ||= {}
    @source_models[table] ||= Class.new(SourceRecord) do
      self.table_name = table
      self.inheritance_column = nil
      def self.name = "PostgresMigration::Source"
    end
  end

  def target_model(table)
    @target_models ||= {}
    @target_models[table] ||= Class.new(ActiveRecord::Base) do
      self.table_name = table
      self.inheritance_column = nil
      def self.name = "PostgresMigration::Target"
    end
  end

  def yen(amount)
    "¥#{amount.to_i.to_fs(:delimited)}"
  end
end
