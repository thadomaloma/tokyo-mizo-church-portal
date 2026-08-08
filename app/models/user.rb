class User < ApplicationRecord
  has_many :notification_reads, dependent: :destroy
  has_many :authored_notifications,
           class_name: "Notification",
           foreign_key: :actor_id,
           inverse_of: :actor,
           dependent: :nullify
  has_many :finance_transactions,
           foreign_key: :recorded_by_id,
           inverse_of: :recorded_by,
           dependent: :restrict_with_error
  has_many :meeting_minutes,
           foreign_key: :uploaded_by_id,
           inverse_of: :uploaded_by,
           dependent: :restrict_with_error
  has_many :church_events,
           foreign_key: :created_by_id,
           inverse_of: :created_by,
           dependent: :restrict_with_error
  has_many :assigned_resolutions,
           class_name: "Resolution",
           foreign_key: :assigned_to_id,
           inverse_of: :assigned_to,
           dependent: :nullify
  has_many :assigned_church_resolutions,
           class_name: "ChurchResolution",
           foreign_key: :assigned_to_id,
           inverse_of: :assigned_to,
           dependent: :nullify

  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  # audited

  enum :role, {
    president: 0,
    vice_president: 1,
    secretary: 2,
    assistant_secretary: 3,
    treasurer: 4,
    finance_secretary: 5,
    journal_secretary: 6,
    executive_member: 7,
    pastor: 8,
    adviser: 9
  }, prefix: true

  ROLE_OPTIONS = [
    [ "President", "president" ],
    [ "Vice President", "vice_president" ],
    [ "Secretary", "secretary" ],
    [ "Assistant Secretary", "assistant_secretary" ],
    [ "Treasurer", "treasurer" ],
    [ "Finance Secretary", "finance_secretary" ],
    [ "Journal Secretary", "journal_secretary" ],
    [ "Executive Member", "executive_member" ],
    [ "Pastor", "pastor" ],
    [ "Adviser", "adviser" ]
  ].freeze

  scope :active, -> { where(active: true) }

  validates :name, presence: true
  validates :role, presence: true

  before_validation :set_default_values, on: :create

  def super_admin?
    role_president? || role_secretary?
  end

  def finance_admin?
    role_treasurer? || role_finance_secretary?
  end

  def office_bearer?
    role_president? ||
      role_vice_president? ||
      role_secretary? ||
      role_assistant_secretary? ||
      role_treasurer? ||
      role_finance_secretary? ||
      role_journal_secretary?
  end

  def executive_committee?
    role_executive_member?
  end

  def notification_actor?
    role_president? ||
    role_secretary? ||
    role_treasurer? ||
    role_finance_secretary?
  end

  private

  def set_default_values
    self.role ||= :executive_member
    self.active = true if active.nil?
  end
end
