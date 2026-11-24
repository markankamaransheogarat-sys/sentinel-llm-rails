# frozen_string_literal: true

require "digest"

module Gateway
  class ChatCompletion
    include Dry::Monads[:result, :do]

    CACHE_HIT_SQL = <<~SQL.squish
      UPDATE prompt_cache_entries
      SET hits = hits + 1,
          tokens_saved = tokens_saved + :tokens,
          updated_at = NOW()
      WHERE model = :model
        AND prompt_sha256 = :sha
        AND expires_at > NOW()
      RETURNING response_payload, hits
    SQL

    UPSERT_CACHE_SQL = <<~SQL.squish
      INSERT INTO prompt_cache_entries (model, prompt_sha256, response_payload, hits, tokens_saved, expires_at, created_at, updated_at)
      VALUES (:model, :sha, CAST(:payload AS jsonb), 0, 0, NOW() + INTERVAL '1 hour', NOW(), NOW())
      ON CONFLICT (model, prompt_sha256)
      DO UPDATE SET response_payload = EXCLUDED.response_payload, expires_at = EXCLUDED.expires_at, updated_at = NOW()
    SQL

    DEFAULT_UPSTREAM = ENV.fetch("LLM_UPSTREAM_URL", "https://api.openai.com/v1/chat/completions")

    def initialize(
      contract: Contracts::Gateway::CompletionContract.new,
      firewall: Security::PromptFirewall.new
    )
      @contract = contract
      @firewall = firewall
    end

    def call(tenant:, params:)
      validated = yield validate(params)
      return Failure([ :model_not_allowed, "Model #{validated[:model]} is not enabled for #{tenant.code}" ]) unless tenant.allowed_models.include?(validated[:model])

      upstream_url = validated[:upstream_url] || DEFAULT_UPSTREAM
      ssrf_check = Security::UrlGuard.validate(upstream_url)
      if ssrf_check.failure?
        audit!(tenant, "ssrf_blocked", "high", upstream_url)
        return ssrf_check
      end

      fw_result = @firewall.inspect_messages(validated[:messages])
      if fw_result.failure?
        audit!(tenant, "prompt_injection", "critical", validated[:messages].last[:content].to_s.truncate(160))
        return fw_result
      end

      sanitized_messages = fw_result.value![:messages]
      secrets_redacted = fw_result.value![:secrets_redacted]
      audit!(tenant, "secret_redacted", "medium", "Redacted #{secrets_redacted} token(s)") if secrets_redacted.positive?

      estimated_tokens = estimate_tokens(sanitized_messages, validated[:max_tokens] || 512)
      sha = Digest::SHA256.hexdigest("#{validated[:model]}:#{sanitized_messages.to_json}")

      if (cached = lookup_cache(model: validated[:model], sha: sha, tokens: estimated_tokens))
        audit!(tenant, "cache_hit", "info", "sha=#{sha[0, 12]}")
        return Success(cached: true, secrets_redacted: secrets_redacted, response: cached)
      end

      quota = Quota::ReserveTokens.call(tenant: tenant, tokens: estimated_tokens)
      if quota.failure?
        audit!(tenant, "budget_exceeded", "high", "estimated=#{estimated_tokens}")
        return quota
      end

      upstream_resp = yield forward_to_upstream(url: upstream_url, model: validated[:model], messages: sanitized_messages, max_tokens: validated[:max_tokens] || 512)
      store_cache(model: validated[:model], sha: sha, payload: upstream_resp)
      audit!(tenant, "upstream_ok", "info", "model=#{validated[:model]}")

      Success(cached: false, secrets_redacted: secrets_redacted, remaining_budget: quota.value![:remaining], response: upstream_resp)
    end

    private

    def validate(params)
      res = @contract.call(params)
      res.success? ? Success(res.to_h) : Failure([ :validation_error, res.errors.to_h ])
    end

    def estimate_tokens(messages, max_tokens)
      chars = messages.sum { |m| m[:content].bytesize }
      (chars / 4.0).ceil + max_tokens
    end

    def lookup_cache(model:, sha:, tokens:)
      sql = ActiveRecord::Base.sanitize_sql_array([ CACHE_HIT_SQL, { model: model, sha: sha, tokens: tokens } ])
      row = ActiveRecord::Base.connection.exec_query(sql).first
      return nil unless row

      raw = row.fetch("response_payload")
      raw.is_a?(String) ? JSON.parse(raw) : raw
    end

    def store_cache(model:, sha:, payload:)
      sql = ActiveRecord::Base.sanitize_sql_array([ UPSERT_CACHE_SQL, { model: model, sha: sha, payload: payload.to_json } ])
      ActiveRecord::Base.connection.exec_update(sql)
    end

    def forward_to_upstream(url:, model:, messages:, max_tokens:)
      conn = Faraday.new do |f|
        f.options.timeout = 10
        f.request :json
        f.response :json
      end

      resp = conn.post(url, { model: model, messages: messages, max_tokens: max_tokens })
      resp.success? ? Success(resp.body) : Failure([ :upstream_error, "HTTP #{resp.status}" ])
    rescue Faraday::Error => e
      Failure([ :upstream_error, e.message ])
    end

    def audit!(tenant, kind, severity, excerpt)
      SecurityAuditLog.create!(api_tenant: tenant, event_kind: kind, severity: severity, redacted_excerpt: excerpt)
    end
  end
end
