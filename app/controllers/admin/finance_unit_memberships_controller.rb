module Admin
  class FinanceUnitMembershipsController < BaseController
    before_action :require_super_admin!
    before_action :set_finance_unit

    def create
      role = membership_role
      unless role.in?(@finance_unit.membership_roles)
        redirect_to admin_finance_units_path, alert: "He finance role hi #{@finance_unit.name} atan a hman theih lo."
        return
      end

      role.in?(FinanceUnitMembership::MANAGER_ROLES) ? replace_manager(role) : add_viewer
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
      message = error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
      redirect_to admin_finance_units_path, alert: message
    end

    def destroy
      membership = @finance_unit.finance_unit_memberships.find(params[:id])
      membership.destroy!

      redirect_to admin_finance_units_path, notice: "Finance unit access paih fel a ni."
    end

    private

    def set_finance_unit
      @finance_unit = FinanceUnit.find(params[:finance_unit_id])
    end

    def membership_payload
      params.require(:finance_unit_membership)
    end

    def membership_user_id
      membership_payload[:user_id].presence
    end

    def membership_role
      membership_payload.require(:role)
    end

    def replace_manager(role)
      @finance_unit.with_lock do
        current_assignment = @finance_unit.finance_unit_memberships.find_by(role: role)

        if membership_user_id.blank?
          current_assignment&.destroy!
        else
          user = User.active.find(membership_user_id)
          reject_conflicting_assignment!(user, role)
          current_assignment&.destroy! unless current_assignment&.user_id == user.id
          membership = @finance_unit.finance_unit_memberships.find_or_initialize_by(user: user)
          membership.role = role
          membership.save!
        end
      end

      redirect_to admin_finance_units_path, notice: "#{@finance_unit.name} #{role.humanize} assignment save fel a ni."
    end

    def add_viewer
      user = User.active.find(membership_user_id)
      @finance_unit.with_lock do
        reject_conflicting_assignment!(user, "viewer")
        @finance_unit.finance_unit_memberships.create!(user: user, role: "viewer")
      end

      redirect_to admin_finance_units_path, notice: "#{user.name} hnenah #{@finance_unit.name} read-only access pek a ni."
    end

    def reject_conflicting_assignment!(user, requested_role)
      existing = @finance_unit.finance_unit_memberships.find_by(user: user)
      return unless existing
      return if existing.role == requested_role

      existing.errors.add(
        :user,
        "chu #{existing.role.humanize} anga assign tawh a ni. Role dang thlan hmain assignment hmasa clear rawh."
      )
      raise ActiveRecord::RecordInvalid, existing
    end
  end
end
