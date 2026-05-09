require "rails_helper"

RSpec.describe MailersendDeliveryMethod do
  subject(:delivery_method) { described_class.new(api_token: "token") }

  let(:client) { instance_double(Mailersend::Client) }
  let(:email) do
    instance_double(
      Mailersend::Email,
      add_from: nil,
      add_recipients: nil,
      add_cc: nil,
      add_bcc: nil,
      add_reply_to: nil,
      add_subject: nil,
      add_text: nil,
      add_html: nil,
      add_attachment: nil
    )
  end
  let(:response) { instance_double("HTTP::Response", status: 202, body: "accepted") }
  let(:mail) do
    Mail.new do
      from "StickerSwap <no-reply@example.com>"
      to "Ana <ana@example.com>"
      cc "Luis <luis@example.com>"
      reply_to "Soporte <support@example.com>"
      subject "Prueba"

      text_part do
        body "Texto plano"
      end

      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p>HTML</p>"
      end
    end
  end

  before do
    allow(Mailersend::Client).to receive(:new).with("token").and_return(client)
    allow(Mailersend::Email).to receive(:new).with(client).and_return(email)
    allow(email).to receive(:send).and_return(response)
  end

  it "maps a Mail message to MailerSend" do
    delivery_method.deliver!(mail)

    expect(email).to have_received(:add_from).with({ "email" => "no-reply@example.com", "name" => "StickerSwap" })
    expect(email).to have_received(:add_recipients).with({ "email" => "ana@example.com", "name" => "Ana" })
    expect(email).to have_received(:add_cc).with({ "email" => "luis@example.com", "name" => "Luis" })
    expect(email).to have_received(:add_reply_to).with({ "email" => "support@example.com", "name" => "Soporte" })
    expect(email).to have_received(:add_subject).with("Prueba")
    expect(email).to have_received(:add_text).with("Texto plano")
    expect(email).to have_received(:add_html).with("<p>HTML</p>")
  end

  it "raises when MailerSend rejects the request" do
    allow(email).to receive(:send).and_return(instance_double("HTTP::Response", status: 422, body: '{"message":"invalid"}'))

    expect { delivery_method.deliver!(mail) }
      .to raise_error(MailersendDeliveryMethod::Error, /422/)
  end
end
