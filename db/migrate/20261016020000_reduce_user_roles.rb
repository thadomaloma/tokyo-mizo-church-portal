# Only four church offices remain: chairman (was president, same value),
# secretary, treasurer and finance secretary. Anyone holding a retired
# title becomes a finance secretary. Titles grant nothing on their own —
# finance access comes from FinanceUnitMembership — so this changes no one's
# permissions; adjust titles in Settings if needed.
class ReduceUserRoles < ActiveRecord::Migration[8.1]
  KEPT_ROLES = [ 0, 2, 4, 5 ].freeze
  FALLBACK_ROLE = 5

  def up
    execute "UPDATE users SET role = #{FALLBACK_ROLE} WHERE role IS NULL OR role NOT IN (#{KEPT_ROLES.join(', ')})"
    change_column_default :users, :role, from: 7, to: nil
  end

  def down
    change_column_default :users, :role, from: nil, to: 7
  end
end
