# frozen_string_literal: true

class PromptCacheEntry < ApplicationRecord
  validates :prompt_sha256, :model, :response_payload, :expires_at, presence: true
end
