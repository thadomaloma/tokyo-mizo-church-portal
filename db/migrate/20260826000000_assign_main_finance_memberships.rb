class AssignMainFinanceMemberships < ActiveRecord::Migration[8.1]
  def up
    main_unit_id = select_value(<<~SQL.squish)
      SELECT id FROM finance_units WHERE slug = 'main-church-finance'
    SQL
    return unless main_unit_id

    execute <<~SQL.squish
      INSERT INTO finance_unit_memberships (finance_unit_id, user_id, role, created_at, updated_at)
      SELECT
        #{connection.quote(main_unit_id)},
        users.id,
        CASE users.role WHEN 4 THEN 'treasurer' ELSE 'finance_secretary' END,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM users
      WHERE users.role IN (4, 5)
      ON CONFLICT (finance_unit_id, user_id)
      DO UPDATE SET role = EXCLUDED.role, updated_at = CURRENT_TIMESTAMP
    SQL
  end

  def down
    # Memberships may have been edited after migration, so removing them here
    # would revoke real user-managed access. This data migration is irreversible.
  end
end
