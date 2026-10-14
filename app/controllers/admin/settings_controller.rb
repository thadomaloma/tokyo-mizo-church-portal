module Admin
  class SettingsController < BaseController
    def show
      return unless current_user.super_admin?

      @users = User.includes(finance_unit_memberships: :finance_unit).order(active: :desc, name: :asc)
    end
  end
end
