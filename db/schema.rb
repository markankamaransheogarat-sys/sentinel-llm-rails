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

ActiveRecord::Schema[7.2].define(version: 2026_11_24_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "api_tenants", force: :cascade do |t|
    t.string "code", null: false
    t.string "api_key_hash", null: false
    t.bigint "daily_token_limit", default: 100000, null: false
    t.bigint "tokens_used_today", default: 0, null: false
    t.date "budget_reset_at", default: -> { "CURRENT_DATE" }, null: false
    t.string "allowed_models", default: ["gpt-4o-mini", "claude-3-5-sonnet", "deepseek-chat"], null: false, array: true
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_hash"], name: "index_api_tenants_on_api_key_hash", unique: true
    t.index ["code"], name: "index_api_tenants_on_code", unique: true
  end

  create_table "prompt_cache_entries", force: :cascade do |t|
    t.string "prompt_sha256", null: false
    t.string "model", null: false
    t.jsonb "response_payload", null: false
    t.bigint "hits", default: 0, null: false
    t.bigint "tokens_saved", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_prompt_cache_entries_on_expires_at"
    t.index ["model", "prompt_sha256"], name: "idx_cache_model_sha_unique", unique: true
  end

  create_table "security_audit_logs", force: :cascade do |t|
    t.bigint "api_tenant_id", null: false
    t.string "event_kind", null: false
    t.string "severity", null: false
    t.text "redacted_excerpt"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["api_tenant_id", "event_kind", "created_at"], name: "idx_audit_tenant_kind"
    t.index ["api_tenant_id"], name: "index_security_audit_logs_on_api_tenant_id"
  end

  add_foreign_key "security_audit_logs", "api_tenants"
end
