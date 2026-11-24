# Sentinel LLM Rails

AI Gateway, Prompt-Injection & SSRF Firewall, Atomic Token Quota Gate & Semantic/Hash Prompt Cache built on **Ruby 3.3, Rails 7.2, Grape API, Dry-rb, PostgreSQL Raw SQL, and RSpec**.

Inspired by `llm-cache-edge`, `mcp-guard`, and `token-sentinel`.

## Key Features
- **Prompt Firewall (`Security::PromptFirewall`)**: Blocks jailbreak/prompt-injection patterns and redacts leaked OpenAI/AWS/GitHub/Bearer secrets before forwarding or logging.
- **SSRF Guard (`Security::UrlGuard`)**: Resolves DNS and blocks loopback, RFC1918 private subnets, IPv6 ULA/link-local, and cloud metadata (`169.254.169.254`).
- **Atomic PostgreSQL Token Quota (`Quota::ReserveTokens`)**: Single-statement SQL reservation with automatic daily reset and zero race conditions.
- **PostgreSQL Prompt Cache (`Gateway::ChatCompletion`)**: SHA-256 response cache with `ON CONFLICT DO UPDATE` and atomic hit/tokens-saved counters.
- **Security Audit Trail (`GET /api/v1/audit/summary`)**: Aggregated SQL audit log per tenant.

## Run Tests & Linters
```bash
bin/rails db:prepare
bundle exec rspec --format documentation
bin/rubocop
```
