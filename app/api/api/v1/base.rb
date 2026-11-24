# frozen_string_literal: true

require "digest"

module Api
  module V1
    class Base < Grape::API
      version "v1", using: :path
      format :json
      prefix :api

      helpers do
        def authenticate_tenant!
          token = headers["Authorization"].to_s.sub(/\ABearer\s+/i, "")
          error!({ error: "unauthorized" }, 401) if token.blank?

          key_hash = Digest::SHA256.hexdigest(token)
          @current_tenant = ApiTenant.find_by(api_key_hash: key_hash, active: true)
          error!({ error: "unauthorized" }, 401) unless @current_tenant
        end

        def current_tenant
          @current_tenant
        end
      end

      get :health do
        ActiveRecord::Base.connection.execute("SELECT 1")
        { status: "ok", service: "sentinel-llm-rails" }
      end

      resource :chat do
        before { authenticate_tenant! }

        post :completions do
          result = ::Gateway::ChatCompletion.new.call(
            tenant: current_tenant,
            params: params.to_h.deep_symbolize_keys
          )

          if result.success?
            status 200
            result.value!
          else
            code, details = result.failure
            http_status = case code
            when :prompt_injection_detected, :ssrf_blocked then 403
            when :budget_exceeded then 429
            when :validation_error, :model_not_allowed then 422
            else 502
            end
            error!({ error: code, details: details }, http_status)
          end
        end
      end

      resource :audit do
        before { authenticate_tenant! }

        get :summary do
          sql = ActiveRecord::Base.sanitize_sql_array([
            "SELECT event_kind, severity, COUNT(*)::int AS total FROM security_audit_logs WHERE api_tenant_id = :id GROUP BY event_kind, severity ORDER BY total DESC",
            { id: current_tenant.id }
          ])
          {
            tenant: current_tenant.code,
            events: ActiveRecord::Base.connection.exec_query(sql).to_a
          }
        end
      end
    end
  end
end
