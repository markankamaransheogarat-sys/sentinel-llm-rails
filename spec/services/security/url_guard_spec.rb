# frozen_string_literal: true

require "rails_helper"

RSpec.describe Security::UrlGuard do
  it "blocks cloud metadata, loopback, and non-HTTPS URLs" do
    expect(described_class.validate("https://169.254.169.254/latest/meta-data")).to be_failure
    expect(described_class.validate("https://127.0.0.1/v1/chat")).to be_failure
    expect(described_class.validate("https://10.0.0.5/internal")).to be_failure
    expect(described_class.validate("http://8.8.8.8/plain")).to be_failure
  end

  it "allows public HTTPS endpoints" do
    allow(Resolv).to receive(:getaddresses).with("api.openai.com").and_return([ "104.18.7.192" ])
    expect(described_class.validate("https://api.openai.com/v1/chat/completions")).to be_success
  end
end
