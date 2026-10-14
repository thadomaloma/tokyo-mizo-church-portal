module AdminHelper
  # Bottom dock on phones: Home, Finance and Reports, with everything else
  # (members, finance access, profile) under the More sheet.
  def mobile_dock_items
    items = [
      {
        name: "Home",
        path: admin_root_path,
        active: current_page?(admin_root_path),
        icon: "home"
      }
    ]

    if finance_access?
      items << {
        name: "Finance",
        path: admin_finance_transactions_path,
        active: request.path.start_with?("/admin/finance_transactions") ||
                request.path.start_with?("/admin/finance_categories") ||
                request.path.start_with?("/admin/finance_periods"),
        icon: "banknotes"
      }

      items << {
        name: "Reports",
        path: admin_reports_path,
        active: request.path.start_with?("/admin/reports"),
        icon: "document-chart-bar"
      }
    end

    items
  end

  def more_menu_active?
    %w[/admin/users /admin/finance_units /admin/profile]
      .any? { |prefix| request.path.start_with?(prefix) } &&
      !mobile_dock_items.any? { |item| item[:active] }
  end

  def more_menu_items
    items = [
      { name: "Members", path: admin_users_path, icon: "users", active: request.path.start_with?("/admin/users") }
    ]

    if current_user.super_admin?
      items << { name: "Finance Access", path: admin_finance_units_path, icon: "building-office-2", active: request.path.start_with?("/admin/finance_units") }
    end

    items << { name: "My Profile", path: admin_profile_path, icon: "user-circle", active: request.path.start_with?("/admin/profile") }

    items
  end

  def can_manage_finance?(finance_unit = current_finance_unit)
    current_user.can_manage_finance_unit?(finance_unit)
  end

  def finance_access_user_options(users, selected_user_id = nil)
    options_for_select(
      users.map do |user|
        status = user.active? ? nil : "Inactive"
        [ [ user.name, user.email, status ].compact.join(" — "), user.id ]
      end,
      selected_user_id
    )
  end

  def can_manage_church?
    current_user.super_admin?
  end
end
