class AddCategoryNameUniqueness < ActiveRecord::Migration[8.1]
  def up
    # Older installations may already contain categories that differ only by
    # letter case. Preserve every finance entry by pointing it at the oldest
    # category in each duplicate group before removing the redundant rows.
    execute <<~SQL
      WITH ranked_categories AS (
        SELECT
          id,
          MIN(id) OVER (
            PARTITION BY finance_unit_id, category_type, lower(name)
          ) AS canonical_id
        FROM finance_categories
      )
      UPDATE finance_transactions
      SET finance_category_id = ranked_categories.canonical_id
      FROM ranked_categories
      WHERE finance_transactions.finance_category_id = ranked_categories.id
        AND ranked_categories.id <> ranked_categories.canonical_id
    SQL

    execute <<~SQL
      WITH ranked_categories AS (
        SELECT
          id,
          MIN(id) OVER (
            PARTITION BY finance_unit_id, category_type, lower(name)
          ) AS canonical_id
        FROM finance_categories
      )
      DELETE FROM finance_categories
      USING ranked_categories
      WHERE finance_categories.id = ranked_categories.id
        AND ranked_categories.id <> ranked_categories.canonical_id
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX index_finance_categories_on_unit_type_lower_name
      ON finance_categories (finance_unit_id, category_type, lower(name))
    SQL
  end

  def down
    execute "DROP INDEX index_finance_categories_on_unit_type_lower_name"
  end
end
