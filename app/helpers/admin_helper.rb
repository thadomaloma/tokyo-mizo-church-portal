module AdminHelper
  MOBILE_PRIORITY_ITEMS = {
    minutes: { name: "Minutes", path: :admin_meeting_minutes_path, prefix: "/admin/meeting_minutes", icon: "document-text" },
    calendar: { name: "Calendar", path: :admin_church_events_path, prefix: "/admin/church_events", icon: "calendar-days" },
    reports: { name: "Reports", path: :admin_reports_path, prefix: "/admin/reports", icon: "document-chart-bar" }
  }.freeze

  # Fixed core (Home, Finance, Alerts) plus one role-dependent slot, so the
  # dock stays at the task's recommended 4-5 items while still surfacing the
  # single most relevant extra destination for each role.
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
                request.path.start_with?("/admin/finance_categories"),
        icon: "banknotes"
      }
    end

    items << {
        name: "Alerts",
        path: admin_notifications_path,
        active: request.path.start_with?("/admin/notifications"),
        icon: "bell",
        badge: @notifications_count
      }
    items << mobile_priority_item
    items
  end

  def mobile_priority_item
    key = mobile_priority_key
    config = MOBILE_PRIORITY_ITEMS.fetch(key)

    {
      name: config[:name],
      path: public_send(config[:path]),
      active: request.path.start_with?(config[:prefix]),
      icon: config[:icon]
    }
  end

  # UX priority only — every role can already view all of these modules
  # (see the controllers' own before_actions); this just decides which one
  # earns the extra bottom-dock slot.
  def mobile_priority_key
    case current_user.role
    when "president", "vice_president", "treasurer", "finance_secretary"
      :reports
    when "secretary", "assistant_secretary", "pastor", "adviser"
      :minutes
    else
      :calendar
    end
  end

  def more_menu_active?
    %w[/admin/secretary_workspace /admin/meeting_minutes /admin/church_resolutions
       /admin/official_letters /admin/church_events
       /admin/users /admin/reports /admin/finance_units /admin/profile]
      .any? { |prefix| request.path.start_with?(prefix) } &&
      !mobile_dock_items.any? { |item| item[:active] }
  end

  def more_menu_items
    items = [
      { name: "Secretary Workspace", path: admin_secretary_workspace_path, icon: "folder-open", active: request.path.start_with?("/admin/secretary_workspace") },
      { name: "Meeting Minutes", path: admin_meeting_minutes_path, icon: "document-text", active: request.path.start_with?("/admin/meeting_minutes") },
      { name: "Resolutions", path: admin_church_resolutions_path, icon: "clipboard-document-check", active: request.path.start_with?("/admin/church_resolutions") },
      { name: "Official Letters", path: admin_official_letters_path, icon: "envelope", active: request.path.start_with?("/admin/official_letters") },
      { name: "Calendar", path: admin_church_events_path, icon: "calendar-days", active: request.path.start_with?("/admin/church_events") },
      { name: "Members", path: admin_users_path, icon: "users", active: request.path.start_with?("/admin/users") },
      { name: "Reports", path: admin_reports_path, icon: "document-chart-bar", active: request.path.start_with?("/admin/reports") }
    ]

    if current_user.super_admin?
      items << { name: "Finance Access", path: admin_finance_units_path, icon: "building-office-2", active: request.path.start_with?("/admin/finance_units") }
    end

    items << { name: "Notification Settings", path: admin_profile_path, icon: "cog-6-tooth", active: request.path.start_with?("/admin/profile") }

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
