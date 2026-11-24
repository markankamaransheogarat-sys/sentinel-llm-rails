# frozen_string_literal: true

module Quota
  class ReserveTokens
    extend Dry::Monads[:result]

    RESERVE_SQL = <<~SQL.squish
      UPDATE api_tenants
      SET
        tokens_used_today = CASE
          WHEN budget_reset_at < CURRENT_DATE THEN :tokens
          ELSE tokens_used_today + :tokens
        END,
        budget_reset_at = CURRENT_DATE,
        updated_at = NOW()
      WHERE id = :id
        AND active = TRUE
        AND (
          CASE WHEN budget_reset_at < CURRENT_DATE THEN 0 ELSE tokens_used_today END
        ) + :tokens <= daily_token_limit
      RETURNING daily_token_limit, tokens_used_today
    SQL

    def self.call(tenant:, tokens:)
      sql = ActiveRecord::Base.sanitize_sql_array([ RESERVE_SQL, { id: tenant.id, tokens: tokens } ])
      rows = ActiveRecord::Base.connection.exec_query(sql).to_a

      if rows.any?
        row = rows.first
        Success(remaining: row["daily_token_limit"].to_i - row["tokens_used_today"].to_i)
      else
        Failure([ :budget_exceeded, "Daily token quota exhausted for tenant #{tenant.code}" ])
      end
    end
  end
end
