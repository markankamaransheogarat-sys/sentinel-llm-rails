# frozen_string_literal: true

module Contracts
  module Gateway
    class CompletionContract < Dry::Validation::Contract
      MessageSchema = Dry::Schema.Params do
        required(:role).filled(:string, included_in?: %w[system user assistant])
        required(:content).filled(:string, max_size?: 32_000)
      end

      params do
        required(:model).filled(:string)
        required(:messages).filled(:array, min_size?: 1, max_size?: 64).each(MessageSchema)
        optional(:max_tokens).filled(:integer, gt?: 0, lteq?: 16_384)
        optional(:upstream_url).filled(:string)
      end
    end
  end
end
