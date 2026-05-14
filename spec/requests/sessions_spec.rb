require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "POST /sesion" do
    it "renders the dashboard HTML after a Turbo login redirect" do
      user = create(:user)

      post session_path,
           params: { email: user.email, password: "password123" },
           headers: { "ACCEPT" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(root_path)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).to include("Sesión iniciada correctamente.")
      expect(response.body).to include("Tu inventario")
    end

    it "sets the custom session_id cookie on login" do
      user = create(:user)

      post session_path, params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:see_other)
      set_cookie_header = Array(response.headers["Set-Cookie"]).join("\n")

      expect(set_cookie_header).to include("session_id=")
      expect(set_cookie_header).not_to include("session_id=; path=/")
    end

    it "marks the custom session cookie as secure only when SSL is enabled" do
      user = create(:user)

      allow(StickerSwap::RuntimeConfig).to receive(:force_ssl?).and_return(true)
      https!

      post session_path, params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:see_other)
      set_cookie_header = Array(response.headers["Set-Cookie"]).join("\n")

      expect(set_cookie_header).to include("session_id=")
      expect(set_cookie_header).to include("secure")
    end
  end
end
