def required_seed_env(name)
  value = ENV[name].to_s.strip
  return value if value.present?

  raise "#{name} must be set before seeding the admin account."
end

FinanceUnit::DEFAULT_UNITS.each do |attributes|
  FinanceUnit.find_or_create_by!(slug: attributes[:slug]) do |unit|
    unit.assign_attributes(attributes.merge(active: true))
  end
end

FinanceUnit.find_each do |finance_unit|
  FinanceCategory.install_system_catalog_for!(finance_unit)
end

admin_email = required_seed_env("SEED_ADMIN_EMAIL")
admin_password = required_seed_env("SEED_ADMIN_PASSWORD")

admin = User.find_or_initialize_by(email: admin_email)
if admin.new_record?
  admin.name = ENV.fetch("SEED_ADMIN_NAME", "Super Admin")
  admin.phone = ENV.fetch("SEED_ADMIN_PHONE", "")
  admin.role = :president
  admin.active = true
  admin.password = admin_password
  admin.password_confirmation = admin_password
elsif ActiveModel::Type::Boolean.new.cast(ENV["RESET_SEED_ADMIN_PASSWORD"])
  admin.password = admin_password
  admin.password_confirmation = admin_password
end

admin.save!
