require "rails_helper"

RSpec.describe StickerSwap::RuntimeConfig do
  around do |example|
    previous_env = ENV.to_h
    ENV.delete("EMAIL_DELIVERY_PROVIDER")
    ENV.delete("BREVO_API_KEY")
    ENV.delete("BREVO_DEBUG")
    ENV.delete("MAILERSEND_API_TOKEN")

    example.run
  ensure
    ENV.replace(previous_env)
  end

  describe ".email_delivery_provider" do
    it "defaults to file when no provider is configured" do
      expect(described_class.email_delivery_provider).to eq("file")
    end

    it "supports Brevo explicitly" do
      ENV["EMAIL_DELIVERY_PROVIDER"] = "brevo"
      ENV["BREVO_API_KEY"] = "brevo-token"

      expect(described_class.email_delivery_provider).to eq("brevo")
      expect(described_class.brevo_enabled?).to be(true)
      expect(described_class.brevo_api_key).to eq("brevo-token")
    end

    it "supports MailerSend explicitly" do
      ENV["EMAIL_DELIVERY_PROVIDER"] = "mailersend"
      ENV["MAILERSEND_API_TOKEN"] = "mailersend-token"

      expect(described_class.email_delivery_provider).to eq("mailersend")
      expect(described_class.mailersend_enabled?).to be(true)
      expect(described_class.mailersend_api_token).to eq("mailersend-token")
    end

    it "rejects unknown providers" do
      ENV["EMAIL_DELIVERY_PROVIDER"] = "unknown"

      expect { described_class.email_delivery_provider }
        .to raise_error(ArgumentError, /EMAIL_DELIVERY_PROVIDER/)
    end
  end

  describe ".brevo_debug?" do
    it "defaults to false" do
      expect(described_class.brevo_debug?).to be(false)
    end

    it "casts common truthy values" do
      ENV["BREVO_DEBUG"] = "true"

      expect(described_class.brevo_debug?).to be(true)
    end
  end
end
