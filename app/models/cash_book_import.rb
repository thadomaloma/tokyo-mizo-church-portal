require "csv"

# Brings one past year of a cash book (kept in Excel before the app) into a
# finance unit, from a CSV with the columns date,type,category,amount,note.
#
# The money from before the app started was entered as an "Opening Balance"
# income in the January after that year. The imported year now carries that
# money, so those opening entries are removed, and when part of the opening
# was in the other account a transfer on 31 December moves it there. The
# total and both account balances today stay exactly as they were.
#
# Everything happens in one database transaction that is rolled back unless
# `commit: true` and every check passes.
class CashBookImport
  class Error < StandardError; end

  Row = Struct.new(:line, :date, :type, :category, :amount, :note, keyword_init: true)

  attr_reader :finance_unit, :recorded_by, :location, :report

  def initialize(csv_path:, finance_unit:, recorded_by:, location: "cash")
    @csv_path = csv_path
    @finance_unit = finance_unit
    @recorded_by = recorded_by
    @location = location.to_s
    @report = []
    raise Error, "Account must be one of #{FinanceTransaction::LOCATIONS.join(', ')}" unless @location.in?(FinanceTransaction::LOCATIONS)
  end

  # Returns true when the import was saved, false after a dry run.
  def run(commit: false)
    rows = parse
    year = single_year(rows)
    closing = rows.sum { |row| row.type == "income" ? row.amount : -row.amount }
    check_year_is_free(year)
    next_opening = finance_unit.finance_transactions.income
                               .where(finance_category: category("income", "opening_balance"), transaction_date: Date.new(year + 1).all_month)
    check_next_opening(next_opening, year, closing)
    before = balances

    ActiveRecord::Base.transaction do
      rows.each { |row| create(row) }
      move_opening_into_year(next_opening, year)
      verify(before, year, closing)
      raise ActiveRecord::Rollback unless commit
    end

    log(commit ? "Saved." : "Dry run: nothing was saved. Run again with COMMIT=1 to save.")
    commit
  end

  private

  def parse
    rows = CSV.foreach(@csv_path, headers: true).with_index(2).map do |record, line|
      Row.new(line: line, date: Date.iso8601(record["date"].to_s), type: record["type"], category: record["category"],
              amount: Integer(record["amount"].to_s, 10), note: record["note"].to_s.squish.presence)
    rescue ArgumentError, Date::Error => error
      raise Error, "Line #{line}: #{error.message}"
    end
    raise Error, "The file has no rows." if rows.empty?

    rows.each do |row|
      raise Error, "Line #{row.line}: type must be income or expense" unless row.type.in?(%w[income expense])
      raise Error, "Line #{row.line}: amount must be more than 0" unless row.amount.positive?

      category(row.type, row.category, line: row.line)
    end
    rows.sort_by { |row| [ row.date, row.type == "income" ? 0 : 1, row.line ] }
  end

  def single_year(rows)
    years = rows.map { |row| row.date.year }.uniq
    raise Error, "All rows must be in one year (found #{years.sort.join(', ')})." unless years.one?

    years.first
  end

  def check_year_is_free(year)
    existing = finance_unit.finance_transactions.where(transaction_date: Date.new(year).all_year).count
    raise Error, "#{finance_unit.name} already has #{existing} entries in #{year}. Nothing was imported." if existing.positive?

    closed = finance_unit.finance_periods.closed.where(year: year).or(finance_unit.finance_periods.closed.where(year: year + 1, month: 1))
    labels = closed.map(&:label)
    raise Error, "Reopen #{labels.to_sentence} first: closed months can't be changed." if labels.any?
  end

  # The January opening entries must carry exactly the year's closing
  # balance, or the import would change today's balance.
  def check_next_opening(next_opening, year, closing)
    opening_total = next_opening.sum(:amount)
    later = finance_unit.finance_transactions.where(transaction_date: Date.new(year + 1)..).exists?

    if next_opening.none?
      raise Error, "There are entries after #{year} but no Opening Balance entry in January #{year + 1}." if later

      return log("No Opening Balance entry in January #{year + 1}; nothing to replace.")
    end
    return if opening_total == closing

    raise Error, "The January #{year + 1} opening balance is #{yen(opening_total)} but the file ends #{year} at #{yen(closing)}. " \
                 "Nothing was imported."
  end

  def create(row)
    finance_unit.finance_transactions.create!(
      transaction_type: row.type, finance_category: category(row.type, row.category), amount: row.amount,
      transaction_date: row.date, payment_location: location, description: row.note, recorded_by: recorded_by
    )
  end

  def move_opening_into_year(next_opening, year)
    entries = next_opening.to_a
    return if entries.empty?

    other_accounts = entries.reject { |entry| entry.payment_location == location }.group_by(&:payment_location)
    entries.each do |entry|
      entry.destroy || raise(Error, entry.errors.full_messages.to_sentence)
      log("Removed the January #{year + 1} opening entry: #{yen(entry.amount)} in #{entry.location_label}.")
    end

    other_accounts.each do |account, opening_entries|
      amount = opening_entries.sum(&:amount)
      finance_unit.finance_transactions.create!(
        transaction_type: "transfer", amount: amount, transaction_date: Date.new(year, 12, 31),
        payment_location: location, transfer_to_location: account, recorded_by: recorded_by,
        description: "#{finance_unit.account_label(account)} balance at the end of #{year} (was the January #{year + 1} opening entry)"
      )
      log("Added a transfer of #{yen(amount)} from #{finance_unit.account_label(location)} to #{finance_unit.account_label(account)} on 31 Dec #{year}.")
    end
  end

  def verify(before, year, closing)
    after = balances
    raise Error, "Balances would change (before #{before}, after #{after}). Nothing was imported." unless after == before

    year_end = FinanceSummary.new(finance_unit).balance_on(Date.new(year, 12, 31))
    raise Error, "#{year} would end at #{yen(year_end)}, not #{yen(closing)}. Nothing was imported." unless year_end == closing

    imported = finance_unit.finance_transactions.income_or_expense.where(transaction_date: Date.new(year).all_year)
    log("#{year}: #{imported.count} entries, income #{yen(imported.income.sum(:amount))}, " \
        "expenses #{yen(imported.expense.sum(:amount))}, year-end balance #{yen(year_end)}.")
    log("Balances today, unchanged: total #{yen(after[:total])}, " \
        "#{FinanceTransaction::LOCATIONS.map { |account| "#{finance_unit.account_label(account)} #{yen(after[account])}" }.join(', ')}.")
  end

  def balances
    summary = FinanceSummary.new(finance_unit)
    { total: summary.current_balance }.merge(FinanceTransaction::LOCATIONS.to_h { |account| [ account, summary.account_balance(account) ] })
  end

  def category(type, code, line: nil)
    @categories ||= {}
    @categories[[ type, code ]] ||= finance_unit.finance_categories.system_defined.find_by(category_type: type, code: code) ||
      raise(Error, "#{"Line #{line}: " if line}#{finance_unit.name} has no #{type} category with the code #{code.inspect}")
  end

  def log(message)
    @report << message
  end

  def yen(amount)
    "¥#{amount.to_fs(:delimited)}"
  end
end
