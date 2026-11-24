# frozen_string_literal: true

class CreateSentinelCore < ActiveRecord::Migration[7.2]
  def change
    create_table :api_tenants do |t|
      t.string :code, null: false
      t.string :api_key_hash, null: false
      t.bigint :daily_token_limit, null: false, default: 100_000
      t.bigint :tokens_used_today, null: false, default: 0
      t.date :budget_reset_at, null: false, default: -> { "CURRENT_DATE" }
      t.string :allowed_models, array: true, null: false, default: %w[gpt-4o-mini claude-3-5-sonnet deepseek-chat]
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :api_tenants, :code, unique: true
    add_index :api_tenants, :api_key_hash, unique: true

    create_table :prompt_cache_entries do |t|
      t.string :prompt_sha256, null: false
      t.string :model, null: false
      t.jsonb :response_payload, null: false
      t.bigint :hits, null: false, default: 0
      t.bigint :tokens_saved, null: false, default: 0
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :prompt_cache_entries, %i[model prompt_sha256], unique: true, name: "idx_cache_model_sha_unique"
    add_index :prompt_cache_entries, :expires_at

    create_table :security_audit_logs do |t|
      t.references :api_tenant, null: false, foreign_key: true
      t.string :event_kind, null: false
      t.string :severity, null: false
      t.text :redacted_excerpt
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :security_audit_logs, %i[api_tenant_id event_kind created_at], name: "idx_audit_tenant_kind"
  end
end
