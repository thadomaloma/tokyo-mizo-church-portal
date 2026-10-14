module AdminHelper
  # Main destinations, in Sumvon's order. Users without finance access only
  # get Home; Settings sits apart in the "More" group and the account menu.
  def primary_nav_items
    items = [ nav_item("Home", admin_root_path, "home", active: current_page?(admin_root_path)) ]
    return items unless finance_access?

    items + [
      nav_item("Transactions", admin_finance_transactions_path, "arrows-right-left",
               prefixes: %w[/admin/finance_transactions /admin/finance_categories /admin/offerings]),
      nav_item("Budget", admin_budget_path, "chart-pie", prefixes: %w[/admin/budget]),
      nav_item("Reports", admin_reports_path, "chart-bar", prefixes: %w[/admin/reports /admin/finance_periods]),
      nav_item("Accounts", admin_accounts_path, "wallet", prefixes: %w[/admin/accounts])
    ]
  end

  def secondary_nav_items
    [ nav_item("Settings", admin_settings_path, "cog-6-tooth", prefixes: %w[/admin/settings /admin/users /admin/finance_units]) ]
  end

  # Phone dock: the four most used destinations around a central Add button.
  def mobile_dock_items
    items = primary_nav_items.reject { |item| item[:name] == "Accounts" }
    finance_access? ? items : items + secondary_nav_items
  end

  def can_add_transaction?
    finance_access? && current_finance_unit.present? && can_manage_finance?
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

  private

  def nav_item(name, path, icon, active: nil, prefixes: [])
    active = prefixes.any? { |prefix| request.path.start_with?(prefix) } if active.nil?

    { name: name, path: path, icon: icon, active: active }
  end
end
