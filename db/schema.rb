# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_010000) do
  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "finance_budget_lines", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.integer "finance_budget_id", null: false
    t.integer "finance_category_id", null: false
    t.datetime "updated_at", null: false
    t.index ["finance_budget_id", "finance_category_id"], name: "index_finance_budget_lines_on_budget_and_category", unique: true
    t.index ["finance_budget_id"], name: "index_finance_budget_lines_on_finance_budget_id"
    t.index ["finance_category_id"], name: "index_finance_budget_lines_on_finance_category_id"
  end

  create_table "finance_budgets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "finance_unit_id", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["finance_unit_id", "year"], name: "index_finance_budgets_on_finance_unit_id_and_year", unique: true
    t.index ["finance_unit_id"], name: "index_finance_budgets_on_finance_unit_id"
  end

  create_table "finance_categories", force: :cascade do |t|
    t.string "category_type"
    t.string "code"
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "finance_unit_id", null: false
    t.string "name"
    t.integer "position", default: 0, null: false
    t.boolean "system_defined", default: false, null: false
    t.datetime "updated_at", null: false
    t.index "finance_unit_id, category_type, lower(name)", name: "index_finance_categories_on_unit_type_lower_name", unique: true
    t.index ["finance_unit_id", "category_type", "code"], name: "index_finance_categories_on_unit_type_code", unique: true, where: "code IS NOT NULL"
    t.index ["finance_unit_id"], name: "index_finance_categories_on_finance_unit_id"
  end

  create_table "finance_periods", force: :cascade do |t|
    t.datetime "closed_at"
    t.bigint "closed_by_id"
    t.datetime "created_at", null: false
    t.bigint "finance_unit_id", null: false
    t.integer "month", null: false
    t.datetime "reopened_at"
    t.bigint "reopened_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["closed_by_id"], name: "index_finance_periods_on_closed_by_id"
    t.index ["finance_unit_id", "year", "month"], name: "index_finance_periods_on_finance_unit_id_and_year_and_month", unique: true
    t.index ["finance_unit_id"], name: "index_finance_periods_on_finance_unit_id"
    t.index ["reopened_by_id"], name: "index_finance_periods_on_reopened_by_id"
  end

  create_table "finance_transactions", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "finance_category_id"
    t.bigint "finance_unit_id", null: false
    t.string "payer_name"
    t.string "payment_location", default: "cash", null: false
    t.bigint "recorded_by_id", null: false
    t.date "transaction_date"
    t.string "transaction_type"
    t.string "transfer_to_location"
    t.datetime "updated_at", null: false
    t.integer "voucher_number"
    t.integer "voucher_year"
    t.index ["finance_category_id"], name: "index_finance_transactions_on_finance_category_id"
    t.index ["finance_unit_id", "transaction_type", "transaction_date"], name: "index_finance_transactions_on_unit_type_date"
    t.index ["finance_unit_id", "voucher_year", "voucher_number"], name: "index_finance_transactions_on_unit_year_expense_voucher", unique: true, where: "transaction_type = 'expense' AND voucher_number IS NOT NULL"
    t.index ["finance_unit_id"], name: "index_finance_transactions_on_finance_unit_id"
    t.index ["payment_location"], name: "index_finance_transactions_on_payment_location"
    t.index ["recorded_by_id"], name: "index_finance_transactions_on_recorded_by_id"
    t.index ["transaction_date"], name: "index_finance_transactions_on_transaction_date"
  end

  create_table "finance_unit_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "finance_unit_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["finance_unit_id", "user_id"], name: "index_finance_unit_memberships_on_unit_and_user", unique: true
    t.index ["finance_unit_id"], name: "index_finance_unit_memberships_on_finance_unit_id"
    t.index ["user_id"], name: "index_finance_unit_memberships_on_user_id"
  end

  create_table "finance_units", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.string "unit_type", default: "department", null: false
    t.datetime "updated_at", null: false
    t.integer "voucher_sequence", default: 0, null: false
    t.index ["active", "position"], name: "index_finance_units_on_active_and_position"
    t.index ["slug"], name: "index_finance_units_on_slug", unique: true
  end

  create_table "finance_voucher_sequences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "finance_unit_id", null: false
    t.integer "next_number", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["finance_unit_id", "year"], name: "index_finance_voucher_sequences_on_finance_unit_id_and_year", unique: true
    t.index ["finance_unit_id"], name: "index_finance_voucher_sequences_on_finance_unit_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "finance_budget_lines", "finance_budgets"
  add_foreign_key "finance_budget_lines", "finance_categories"
  add_foreign_key "finance_budgets", "finance_units"
  add_foreign_key "finance_categories", "finance_units"
  add_foreign_key "finance_periods", "finance_units"
  add_foreign_key "finance_periods", "users", column: "closed_by_id"
  add_foreign_key "finance_periods", "users", column: "reopened_by_id"
  add_foreign_key "finance_transactions", "finance_categories"
  add_foreign_key "finance_transactions", "finance_units"
  add_foreign_key "finance_transactions", "users", column: "recorded_by_id"
  add_foreign_key "finance_unit_memberships", "finance_units"
  add_foreign_key "finance_unit_memberships", "users"
  add_foreign_key "finance_voucher_sequences", "finance_units"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
