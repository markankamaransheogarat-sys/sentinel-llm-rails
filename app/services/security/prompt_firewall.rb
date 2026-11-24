# frozen_string_literal: true

module Security
  class PromptFirewall
    include Dry::Monads[:result]

    INJECTION_PATTERNS = [
      /ignore\s+(all\s+)?(previous|prior|above)\s+instructions/i,
      /reveal\s+(your\s+)?system\s+prompt/i,
      /bypass\s+(security|policy|guardrails)/i,
      /<\s*\|?\s*system\s*\|?\s*>/i
    ].freeze

    SECRET_PATTERNS = [
      [ /\bsk-[A-Za-z0-9]{16,}\b/, "[REDACTED_OPENAI_KEY]" ],
      [ /\bAKIA[0-9A-Z]{16}\b/, "[REDACTED_AWS_KEY]" ],
      [ /\bgh[pousr]_[A-Za-z0-9]{20,}\b/, "[REDACTED_GH_TOKEN]" ],
      [ /Bearer\s+[A-Za-z0-9\-._~+\/]+=*/i, "Bearer [REDACTED_TOKEN]" ]
    ].freeze

    def inspect_messages(messages)
      redacted_count = 0

      sanitized = messages.map do |msg|
        content = msg[:content].to_s.dup
        matched = INJECTION_PATTERNS.find { |rx| content.match?(rx) }
        return Failure([ :prompt_injection_detected, "Blocked by prompt injection rule: #{matched.source}" ]) if matched

        SECRET_PATTERNS.each do |rx, replacement|
          content.gsub!(rx) do
            redacted_count += 1
            replacement
          end
        end

        msg.merge(content: content)
      end

      Success(messages: sanitized, secrets_redacted: redacted_count)
    end
  end
end
