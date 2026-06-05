admin_email = ENV.fetch("SEED_ADMIN_EMAIL", "admin@tokyomizochurch.org")
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "TokyoMizo@2026")

admin = User.find_or_initialize_by(email: admin_email)
admin.name = ENV.fetch("SEED_ADMIN_NAME", "Super Admin")
admin.phone = ENV.fetch("SEED_ADMIN_PHONE", "")
admin.password = admin_password
admin.password_confirmation = admin_password
admin.role = :president
admin.active = true
admin.save!

User.find_or_create_by!(email: "demo@tokyomizochurch.org") do |user|
  user.password = "Demo@2026"
  user.role = :member
  user.active = true
end
