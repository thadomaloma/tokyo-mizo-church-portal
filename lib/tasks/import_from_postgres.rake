# Moving the finance data off the old PostgreSQL database (Railway).
# See PostgresMigration (lib/postgres_migration.rb) and bin/railway-dry-run.
#
# Run from a development machine, where the pg gem is installed, into an
# empty schema (db:schema:load, not db:prepare, which seeds categories):
#
#   RAILS_ENV=production DATABASE_PATH=tmp/cutover/production.sqlite3 SECRET_KEY_BASE_DUMMY=1 bin/rails db:schema:load
#   SOURCE_DATABASE_URL=postgres:///tmc_railway_copy RAILS_ENV=production \
#     DATABASE_PATH=tmp/cutover/production.sqlite3 SECRET_KEY_BASE_DUMMY=1 bin/rails db:import_from_postgres db:verify_import
namespace :db do
  desc "Copy the finance data from SOURCE_DATABASE_URL (PostgreSQL) into the SQLite database"
  task import_from_postgres: :environment do
    with_migration do |migration|
      migration.import!(force: ENV["FORCE"] == "1")
      puts "Import finished."
    end
  end

  desc "Check every copied row and the finance totals against SOURCE_DATABASE_URL"
  task verify_import: :environment do
    with_migration do |migration|
      problems = migration.verify
      puts
      if problems.empty?
        puts "VERIFIED: every copied row and every finance total matches PostgreSQL."
      else
        puts "NOT VERIFIED — #{problems.size} problem(s):"
        problems.each { |problem| puts "  - #{problem}" }
        exit 1
      end
    end
  end

  def with_migration
    require "pg"
    url = ENV["SOURCE_DATABASE_URL"].presence || abort("Set SOURCE_DATABASE_URL to the PostgreSQL copy.")
    migration = PostgresMigration.new(url)
    yield migration
  ensure
    migration&.close
  end
end
