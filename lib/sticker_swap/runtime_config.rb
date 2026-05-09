module StickerSwap
  module RuntimeConfig
    EMAIL_DELIVERY_PROVIDERS = %w[ file brevo mailersend smtp ].freeze

    module_function

    def app_domain
      value = ENV["APP_DOMAIN"].to_s.strip
      return value unless value.empty?

      return "localhost" unless Rails.env.production?

      raise KeyError, "APP_DOMAIN must be set in production"
    end

    def app_protocol
      value = ENV["APP_PROTOCOL"].to_s.strip
      return value unless value.empty?

      Rails.env.production? ? "https" : "http"
    end

    def app_port
      value = ENV["APP_PORT"].to_s.strip
      return value unless value.empty?

      return "3000" unless Rails.env.production?

      nil
    end

    def default_url_options
      options = {
        host: app_domain,
        protocol: app_protocol
      }

      port = app_port
      options[:port] = port if include_port?(port)
      options
    end

    def mailer_from
      value = ENV["MAILER_FROM"].to_s.strip
      return value unless value.empty?

      "no-reply@#{app_domain}"
    end

    def registration_code
      normalize_invitation_code(ENV.fetch("REGISTRATION_CODE", "STICKERSWAP2026"))
    end

    def valid_registration_code?(raw_code)
      normalize_invitation_code(raw_code) == registration_code
    end

    def email_delivery_provider
      provider = ENV["EMAIL_DELIVERY_PROVIDER"].to_s.strip.downcase
      provider = inferred_email_delivery_provider if provider.empty?

      return provider if EMAIL_DELIVERY_PROVIDERS.include?(provider)

      raise ArgumentError,
            "EMAIL_DELIVERY_PROVIDER must be one of: #{EMAIL_DELIVERY_PROVIDERS.join(', ')}"
    end

    def transactional_email_enabled?
      %w[ brevo mailersend smtp ].include?(email_delivery_provider)
    end

    def brevo_enabled?
      email_delivery_provider == "brevo"
    end

    def mailersend_enabled?
      email_delivery_provider == "mailersend"
    end

    def smtp_enabled?
      email_delivery_provider == "smtp"
    end

    def brevo_api_key
      value = ENV["BREVO_API_KEY"].to_s.strip
      return value unless value.empty?
      return nil unless brevo_enabled?

      raise KeyError, "BREVO_API_KEY must be set when EMAIL_DELIVERY_PROVIDER=brevo"
    end

    def brevo_debug?
      ActiveModel::Type::Boolean.new.cast(ENV["BREVO_DEBUG"]) || false
    end

    def mailersend_api_token
      value = ENV["MAILERSEND_API_TOKEN"].to_s.strip
      return value unless value.empty?
      return nil unless mailersend_enabled?

      raise KeyError,
            "MAILERSEND_API_TOKEN must be set when EMAIL_DELIVERY_PROVIDER=mailersend"
    end

    def smtp_settings
      return {} unless smtp_enabled?

      validate_smtp_credentials!

      {
        address: smtp_address,
        port: smtp_port,
        domain: smtp_domain,
        user_name: smtp_username,
        password: smtp_password,
        authentication: smtp_authentication,
        enable_starttls_auto: smtp_enable_starttls_auto?
      }.compact
    end

    def force_ssl?
      app_protocol == "https"
    end

    def inferred_email_delivery_provider
      return "brevo" if !ENV["BREVO_API_KEY"].to_s.strip.empty?
      return "mailersend" if !ENV["MAILERSEND_API_TOKEN"].to_s.strip.empty?
      return "smtp" if !ENV["SMTP_ADDRESS"].to_s.strip.empty?

      "file"
    end
    private_class_method :inferred_email_delivery_provider

    def normalize_invitation_code(raw_code)
      raw_code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end
    private_class_method :normalize_invitation_code

    def include_port?(port)
      return false if port.nil? || port.empty?
      return false if app_protocol == "http" && port == "80"
      return false if app_protocol == "https" && port == "443"

      true
    end
    private_class_method :include_port?

    def smtp_address
      value = ENV["SMTP_ADDRESS"].to_s.strip
      return value unless value.empty?
      return nil unless smtp_enabled?

      raise KeyError, "SMTP_ADDRESS must be set when EMAIL_DELIVERY_PROVIDER=smtp"
    end
    private_class_method :smtp_address

    def smtp_port
      value = ENV["SMTP_PORT"].to_s.strip
      value = "587" if value.empty?

      port = Integer(value, exception: false)
      return port if port&.positive?

      raise ArgumentError, "SMTP_PORT must be a positive integer"
    end
    private_class_method :smtp_port

    def smtp_domain
      value = ENV["SMTP_DOMAIN"].to_s.strip
      return value unless value.empty?

      app_domain
    end
    private_class_method :smtp_domain

    def smtp_username
      value = ENV["SMTP_USERNAME"].to_s.strip
      value.presence
    end
    private_class_method :smtp_username

    def smtp_password
      value = ENV["SMTP_PASSWORD"].to_s.strip
      value.presence
    end
    private_class_method :smtp_password

    def smtp_authentication
      value = ENV["SMTP_AUTHENTICATION"].to_s.strip
      return value.downcase.to_sym unless value.empty?
      return :plain if smtp_username.present?

      nil
    end
    private_class_method :smtp_authentication

    def smtp_enable_starttls_auto?
      value = ENV["SMTP_ENABLE_STARTTLS_AUTO"].to_s.strip
      return true if value.empty?

      ActiveModel::Type::Boolean.new.cast(value)
    end
    private_class_method :smtp_enable_starttls_auto?

    def validate_smtp_credentials!
      return if smtp_username.present? == smtp_password.present?

      raise KeyError, "SMTP_USERNAME and SMTP_PASSWORD must both be set when EMAIL_DELIVERY_PROVIDER=smtp"
    end
    private_class_method :validate_smtp_credentials!
  end
end
