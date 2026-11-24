# frozen_string_literal: true

require "ipaddr"
require "resolv"
require "uri"

module Security
  class UrlGuard
    extend Dry::Monads[:result]

    BLOCKED_RANGES = [
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("::1/128"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10")
    ].freeze

    def self.validate(url)
      uri = URI.parse(url.to_s)
      return Failure([ :ssrf_blocked, "Only HTTPS upstream URLs are allowed" ]) unless uri.is_a?(URI::HTTPS) && uri.host.present?

      addresses = Resolv.getaddresses(uri.host)
      return Failure([ :ssrf_blocked, "Cannot resolve host" ]) if addresses.empty?

      addresses.each do |addr|
        ip = IPAddr.new(addr)
        if BLOCKED_RANGES.any? { |range| range.include?(ip) }
          return Failure([ :ssrf_blocked, "Private or metadata IP #{addr} is forbidden" ])
        end
      end

      Success(uri.to_s)
    rescue URI::InvalidURIError, IPAddr::InvalidAddressError => e
      Failure([ :ssrf_blocked, e.message ])
    end
  end
end
