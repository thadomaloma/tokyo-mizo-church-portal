namespace :finance do
  # Brings a past year of the Excel cash book into the app (see CashBookImport).
  # Dry run by default; COMMIT=1 saves. UNIT is a finance unit slug (default:
  # Main Church Finance) and ACCOUNT is cash or bank (default: cash).
  #
  #   bin/rails "finance:import_cash_book[/rails/storage/cash_book_2025.csv,chairman@example.com]"
  #   COMMIT=1 bin/rails "finance:import_cash_book[/rails/storage/cash_book_2025.csv,chairman@example.com]"
  desc "Import a year of the cash book from CSV (dry run unless COMMIT=1)"
  task :import_cash_book, %i[csv_path recorded_by_email] => :environment do |_task, args|
    abort "Usage: bin/rails \"finance:import_cash_book[path/to/file.csv,recorder@email]\"" if args.values_at(:csv_path, :recorded_by_email).any?(&:blank?)

    import = CashBookImport.new(
      csv_path: args[:csv_path],
      finance_unit: ENV["UNIT"].present? ? FinanceUnit.find_by!(slug: ENV["UNIT"]) : FinanceUnit.main,
      recorded_by: User.find_by!(email: args[:recorded_by_email]),
      location: ENV.fetch("ACCOUNT", "cash")
    )

    begin
      import.run(commit: ENV["COMMIT"] == "1")
    ensure
      puts import.report
    end
  rescue CashBookImport::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => error
    abort "Not imported: #{error.message}"
  end
end
