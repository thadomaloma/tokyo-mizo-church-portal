class AddNumberToChurchResolutions < ActiveRecord::Migration[8.1]
  class MigrationChurchResolution < ActiveRecord::Base
    self.table_name = "church_resolutions"
  end

  def up
    add_column :church_resolutions, :number, :string

    backfill_numbers

    change_column_null :church_resolutions, :number, false
    add_index :church_resolutions, :number, unique: true
  end

  def down
    remove_index :church_resolutions, :number
    remove_column :church_resolutions, :number
  end

  private

  def backfill_numbers
    counters = Hash.new(0)

    MigrationChurchResolution.reset_column_information
    MigrationChurchResolution.order(:created_at, :id).find_each do |resolution|
      year = resolution.created_at.year
      counters[year] += 1
      resolution.update_column(:number, format("RES-%<year>d-%<seq>03d", year: year, seq: counters[year]))
    end
  end
end
