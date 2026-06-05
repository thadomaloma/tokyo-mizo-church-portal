admin_email = ENV.fetch("SEED_ADMIN_EMAIL", "admin@tokyomizochurch.org")
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "TokyoMizo@2026")

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
