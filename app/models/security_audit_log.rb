# frozen_string_literal: true

class SecurityAuditLog < ApplicationRecord
  belongs_to :api_tenant
end
