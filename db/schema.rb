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

ActiveRecord::Schema[8.1].define(version: 2026_06_04_003000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "church_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.datetime "end_date"
    t.string "event_type"
    t.string "location"
    t.datetime "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "visibility"
    t.index ["created_by_id"], name: "index_church_events_on_created_by_id"
  end

  create_table "church_resolutions", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.bigint "meeting_minute_id"
    t.integer "priority", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_church_resolutions_on_assigned_to_id"
    t.index ["meeting_minute_id"], name: "index_church_resolutions_on_meeting_minute_id"
  end

  create_table "finance_categories", force: :cascade do |t|
    t.string "category_type"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "finance_transactions", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "finance_category_id", null: false
    t.string "payer_name"
    t.string "payment_location", default: "cash", null: false
    t.bigint "recorded_by_id", null: false
    t.date "transaction_date"
    t.string "transaction_type"
    t.datetime "updated_at", null: false
    t.index ["finance_category_id"], name: "index_finance_transactions_on_finance_category_id"
    t.index ["payment_location"], name: "index_finance_transactions_on_payment_location"
    t.index ["recorded_by_id"], name: "index_finance_transactions_on_recorded_by_id"
  end

  create_table "meeting_minutes", force: :cascade do |t|
    t.text "absentees"
    t.text "action_items"
    t.text "adjournment"
    t.text "agenda_items"
    t.text "any_other_business"
    t.date "approval_date"
    t.string "approved_by"
    t.boolean "archive_only", default: false, null: false
    t.text "attendees"
    t.text "call_to_order"
    t.string "chairperson"
    t.text "correspondence"
    t.datetime "created_at", null: false
    t.text "description"
    t.time "end_time"
    t.text "guests"
    t.string "location"
    t.date "meeting_date"
    t.string "meeting_type"
    t.text "motions"
    t.text "new_business"
    t.date "next_meeting_date"
    t.text "old_business"
    t.string "opening_prayer"
    t.jsonb "present_member_ids", default: [], null: false
    t.text "previous_minutes"
    t.string "quorum_status"
    t.text "reports"
    t.text "safeguarding_notes"
    t.string "secretary_name"
    t.time "start_time"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id", null: false
    t.index ["uploaded_by_id"], name: "index_meeting_minutes_on_uploaded_by_id"
  end

  create_table "notification_reads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "notification_id", null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notification_id"], name: "index_notification_reads_on_notification_id"
    t.index ["user_id"], name: "index_notification_reads_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "link"
    t.text "message"
    t.string "notification_type"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
  end

  create_table "resolutions", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.bigint "meeting_minute_id", null: false
    t.integer "priority"
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_resolutions_on_assigned_to_id"
    t.index ["meeting_minute_id"], name: "index_resolutions_on_meeting_minute_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 7
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "church_events", "users", column: "created_by_id"
  add_foreign_key "church_resolutions", "meeting_minutes"
  add_foreign_key "church_resolutions", "users", column: "assigned_to_id"
  add_foreign_key "finance_transactions", "finance_categories"
  add_foreign_key "finance_transactions", "users", column: "recorded_by_id"
  add_foreign_key "meeting_minutes", "users", column: "uploaded_by_id"
  add_foreign_key "notification_reads", "notifications"
  add_foreign_key "notification_reads", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "resolutions", "meeting_minutes"
  add_foreign_key "resolutions", "users", column: "assigned_to_id"
end
