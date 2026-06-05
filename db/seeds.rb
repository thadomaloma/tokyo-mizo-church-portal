def required_seed_env(name)
  value = ENV[name].to_s.strip
  return value if value.present?

  raise "#{name} must be set before seeding the admin account."
end

admin_email = required_seed_env("SEED_ADMIN_EMAIL")
admin_password = required_seed_env("SEED_ADMIN_PASSWORD")

admin = User.find_or_initialize_by(email: admin_email)
admin.name = ENV.fetch("SEED_ADMIN_NAME", "Super Admin")
admin.phone = ENV.fetch("SEED_ADMIN_PHONE", "")
admin.role = :president
admin.active = true

if admin.new_record? || ENV["SEED_ADMIN_PASSWORD"].present?
  admin.password = admin_password
  admin.password_confirmation = admin_password
end

admin.save!

User.where(email: "demo@tokyomizochurch.org").destroy_all
