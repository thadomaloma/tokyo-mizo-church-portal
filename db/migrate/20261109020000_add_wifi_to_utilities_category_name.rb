# The Utilities expense category also covers the Wifi bill. System category
# names come from FinanceCategory::SYSTEM_CATALOG; this renames the ones
# already in the database.
class AddWifiToUtilitiesCategoryName < ActiveRecord::Migration[8.1]
  OLD_NAME = "Utilities (Electric, Gas & Water)".freeze
  NEW_NAME = "Utilities (Electric, Gas, Water & Wifi)".freeze

  def up
    execute <<~SQL.squish
      UPDATE finance_categories SET name = #{quote(NEW_NAME)}, updated_at = CURRENT_TIMESTAMP
      WHERE code = 'utilities' AND system_defined = 1 AND name = #{quote(OLD_NAME)}
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE finance_categories SET name = #{quote(OLD_NAME)}, updated_at = CURRENT_TIMESTAMP
      WHERE code = 'utilities' AND system_defined = 1 AND name = #{quote(NEW_NAME)}
    SQL
  end

  private

  def quote(value)
    connection.quote(value)
  end
end
