module AdminHelper
  def mobile_nav_items
    [
      {
        name: "Home",
        path: admin_root_path,
        active: current_page?(admin_root_path),
        icon: "home"
      },
      {
        name: "Finance",
        path: admin_finance_transactions_path,
        active: request.path.start_with?("/admin/finance_transactions") ||
                request.path.start_with?("/admin/finance_categories"),
        icon: "banknotes"
      },
      {
        name: "Minutes",
        path: admin_meeting_minutes_path,
        active: request.path.start_with?("/admin/meeting_minutes"),
        icon: "document-text"
      },
      {
        name: "Letters",
        path: admin_official_letters_path,
        active: request.path.start_with?("/admin/official_letters") ||
                request.path.start_with?("/admin/official_letter_templates"),
        icon: "envelope"
      },
      {
        name: "Calendar",
        path: admin_church_events_path,
        active: request.path.start_with?("/admin/church_events"),
        icon: "calendar-days"
      },
      {
        name: "Reports",
        path: admin_reports_path,
        active: request.path.start_with?("/admin/reports"),
        icon: "document-chart-bar"
      }
    ]
  end

  def can_manage_finance?
    current_user.super_admin? || current_user.finance_admin?
  end

  def can_manage_church?
    current_user.super_admin?
  end

  def can_manage_letters?
    current_user.letter_admin?
  end
end
