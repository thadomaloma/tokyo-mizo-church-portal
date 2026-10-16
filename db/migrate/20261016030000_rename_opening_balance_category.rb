# The system "Opening Balance" category still carried a Mizo suffix in its
# name. Only the name changes; entries keep pointing at the same category.
class RenameOpeningBalanceCategory < ActiveRecord::Migration[8.1]
  OLD_NAME = "Opening Balance (Balance Hmasa)"
  NEW_NAME = "Opening Balance"

  def up
    execute <<~SQL
      UPDATE finance_categories SET name = '#{NEW_NAME}'
      WHERE code = 'opening_balance' AND system_defined = 1 AND name = '#{OLD_NAME}'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE finance_categories SET name = '#{OLD_NAME}'
      WHERE code = 'opening_balance' AND system_defined = 1 AND name = '#{NEW_NAME}'
    SQL
  end
end
