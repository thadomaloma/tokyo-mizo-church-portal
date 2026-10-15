class User < ApplicationRecord
  has_many :finance_unit_memberships, dependent: :destroy
  has_many :finance_units, through: :finance_unit_memberships
  has_many :finance_transactions,
           foreign_key: :recorded_by_id,
           inverse_of: :recorded_by,
           dependent: :restrict_with_error

  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  # Church office of the person. Chairman and Secretary administer the app;
  # everyone else gets finance access per unit (FinanceUnitMembership).
  enum :role, { chairman: 0, secretary: 2, treasurer: 4, finance_secretary: 5 }, prefix: true, validate: true

  attribute :active, default: true

  scope :active, -> { where(active: true) }

  validates :name, presence: true

  def self.role_options
    roles.keys.map { |role| [ role.titleize, role ] }
  end

  def super_admin?
    role_chairman? || role_secretary?
  end

  def accessible_finance_units
    return FinanceUnit.ordered if super_admin?

    FinanceUnit.active
               .joins(:finance_unit_memberships)
               .where(finance_unit_memberships: { user_id: id })
               .ordered
  end

  def preferred_finance_unit
    return FinanceUnit.main if super_admin?

    accessible_finance_units.first
  end

  def can_view_finance_unit?(finance_unit)
    finance_unit.present? && accessible_finance_units.exists?(finance_unit.id)
  end

  def can_manage_finance_unit?(finance_unit)
    return false unless finance_unit
    return true if super_admin?

    finance_unit_memberships.managers.exists?(finance_unit_id: finance_unit.id)
  end

  def finance_access?
    super_admin? || finance_unit_memberships.joins(:finance_unit).merge(FinanceUnit.active).exists?
  end
end
