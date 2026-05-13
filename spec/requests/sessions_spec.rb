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
  end
end
