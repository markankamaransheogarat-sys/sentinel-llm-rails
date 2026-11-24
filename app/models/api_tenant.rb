# frozen_string_literal: true

class ApiTenant < ApplicationRecord
  has_many :security_audit_logs, dependent: :restrict_with_exception

  validates :code, :api_key_hash, presence: true, uniqueness: true
  validates :daily_token_limit, numericality: { greater_than: 0 }
end
