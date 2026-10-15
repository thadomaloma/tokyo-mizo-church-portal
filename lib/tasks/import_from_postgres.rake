# One-off copy of the finance data out of the old PostgreSQL database (Railway)
# into the current SQLite database. Run it from a development machine, where
# the pg gem is installed. Start from an empty schema (not db:prepare, which
# seeds default units and categories):
#
#   RAILS_ENV=production DATABASE_PATH=storage/production.sqlite3 \
#     SECRET_KEY_BASE_DUMMY=1 bin/rails db:schema:load
#   SOURCE_DATABASE_URL="postgres://..." RAILS_ENV=production \
#     DATABASE_PATH=storage/production.sqlite3 SECRET_KEY_BASE_DUMMY=1 \
#     bin/rails db:import_from_postgres
#
# Only the finance tables (plus users and audits) are copied; the removed
# secretary modules and their uploaded files are left behind. Expense
# vouchers are generated pages, so there are no files to move.
namespace :db do
  desc "Copy finance data from SOURCE_DATABASE_URL (PostgreSQL) into the SQLite database"
  task import_from_postgres: :environment do
    require "pg"

    source_url = ENV["SOURCE_DATABASE_URL"].presence ||
                 abort("Set SOURCE_DATABASE_URL to the old PostgreSQL connection URL.")

    # Parent tables first so foreign keys always point at rows already copied.
    tables = %w[
      users
      finance_units
      finance_unit_memberships
      finance_categories
      finance_voucher_sequences
      finance_periods
      finance_transactions
      audits
    ]

    source_base = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      def self.name = "PostgresImportSource"
    end
    source_base.establish_connection(source_url)

    model_for = lambda do |base, table|
      Class.new(base) do
        self.table_name = table
        self.inheritance_column = nil

        define_singleton_method(:name) { "Import#{table.camelize}" }
      end
    end

    target = ActiveRecord::Base.connection
    not_empty = tables.select { |table| target.select_value("SELECT COUNT(*) FROM #{target.quote_table_name(table)}").to_i.positive? }
    if not_empty.any? && ENV["FORCE"] != "1"
      abort "Target database already has data in: #{not_empty.join(", ")}. Use a fresh database, or FORCE=1 to wipe those tables first."
    end

    ActiveRecord::Base.transaction do
      tables.reverse_each { |table| target.delete("DELETE FROM #{target.quote_table_name(table)}") } if not_empty.any?

      tables.each do |table|
        source_model = model_for.call(source_base, table)
        target_model = model_for.call(ActiveRecord::Base, table)

        unless source_model.table_exists?
          puts "#{table}: not in source, skipped"
          next
        end

        columns = source_model.column_names & target_model.column_names
        copied = 0

        source_model.in_batches(of: 500) do |batch|
          rows = batch.pluck(*columns).map { |values| columns.zip(values).to_h }
          # Retired church titles become finance secretary (see ReduceUserRoles).
          rows.each { |row| row["role"] = 5 unless [ 0, 2, 4, 5 ].include?(row["role"]) } if table == "users"
          target_model.insert_all!(rows, record_timestamps: false)
          copied += rows.size
        end

        source_count = source_model.count
        raise "#{table}: copied #{copied} of #{source_count} rows" unless copied == source_count

        puts "#{table}: #{copied} rows"
      end
    end

    puts "Done."
  ensure
    source_base&.remove_connection
  end
end
