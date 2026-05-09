require "base64"
require "mail"
require "mailersend-ruby"

class MailersendDeliveryMethod
  Error = Class.new(StandardError)

  def initialize(settings = {})
    @settings = settings.transform_keys(&:to_sym)
  end

  def deliver!(mail)
    response = build_email(mail).send
    status = response_status(response)

    return response if status.between?(200, 299)

    raise Error,
          "MailerSend delivery failed with status #{status}: #{response_body(response)}"
  end

  private
    attr_reader :settings

    def build_email(mail)
      email = Mailersend::Email.new(client)
      from_address = parsed_addresses(mail[:from]).first

      raise Error, "Mailersend delivery requires a from address" unless from_address

      email.add_from(address_hash(from_address))
      parsed_addresses(mail[:to]).each { |address| email.add_recipients(address_hash(address)) }
      parsed_addresses(mail[:cc]).each { |address| email.add_cc(address_hash(address)) }
      parsed_addresses(mail[:bcc]).each { |address| email.add_bcc(address_hash(address)) }

      reply_to_address = parsed_addresses(mail[:reply_to]).first
      email.add_reply_to(address_hash(reply_to_address)) if reply_to_address

      email.add_subject(mail.subject.to_s)

      text_body = text_body_for(mail)
      html_body = html_body_for(mail)

      email.add_text(text_body) unless text_body.nil? || text_body.empty?
      email.add_html(html_body) unless html_body.nil? || html_body.empty?

      mail.attachments.each do |attachment|
        email.add_attachment(
          content: Base64.strict_encode64(attachment.body.decoded),
          filename: attachment.filename,
          disposition: attachment.inline? ? "inline" : "attachment"
        )
      end

      email
    end

    def client
      @client ||= Mailersend::Client.new(settings.fetch(:api_token))
    end

    def parsed_addresses(header)
      return [] unless header

      Mail::AddressList.new(header.to_s).addresses
    end

    def address_hash(address)
      name = address.display_name.to_s.strip
      {
        "email" => address.address,
        "name" => name.empty? ? nil : name
      }.compact
    end

    def text_body_for(mail)
      return mail.text_part.body.decoded.to_s if mail.text_part
      return unless mail.mime_type == "text/plain"

      mail.body.decoded.to_s
    end

    def html_body_for(mail)
      return mail.html_part.body.decoded.to_s if mail.html_part
      return unless mail.mime_type == "text/html"

      mail.body.decoded.to_s
    end

    def response_status(response)
      if response.respond_to?(:status)
        response.status.to_i
      else
        response.code.to_i
      end
    end

    def response_body(response)
      return response.body.to_s if response.respond_to?(:body)

      response.to_s
    end
end
