class FinanceUnitMembership < ApplicationRecord
  ROLES = %w[treasurer finance_secretary viewer].freeze
  MANAGER_ROLES = %w[treasurer finance_secretary].freeze

  belongs_to :finance_unit
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id,
            uniqueness: {
              scope: :finance_unit_id,
              message: "already has a role in this finance unit"
            }
  validate :role_is_available_for_finance_unit
  validate :manager_role_has_one_assignee

  scope :managers, -> { where(role: MANAGER_ROLES) }

  def manager?
    role.in?(MANAGER_ROLES)
  end

  private

  def role_is_available_for_finance_unit
    return if finance_unit.blank? || role.blank? || role.in?(finance_unit.membership_roles)

    errors.add(:role, "is not available for this finance unit")
  end

  def manager_role_has_one_assignee
    return unless finance_unit && manager?
    return unless finance_unit.finance_unit_memberships.where(role: role).where.not(id: id).exists?

    errors.add(:role, "already has an assigned #{role.humanize}")
  end
end
