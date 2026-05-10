require "rails_helper"

RSpec.describe "Statistics", type: :request do
  describe "GET /estadisticas" do
    it "redirects to the dashboard when there is not enough inventory data" do
      user = create(:user)
      sign_in_as(user)

      get statistics_path

      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response.body).to include("Las estadísticas se habilitan cuando al menos 5 usuarios")
    end

    it "renders the easiest and hardest stickers when enough users have both lists" do
      stats_user = create(:user)
      easiest = create(:sticker, prefix: "ARG", number: 1, name: "Argentina")
      hardest = create(:sticker, prefix: "BRA", number: 2, name: "Brasil")

      5.times do
        user = create(:user)
        create(:inventory_item, :duplicate, user: user, sticker: easiest, quantity: 2)
        create(:inventory_item, user: user, sticker: hardest)
      end

      sign_in_as(stats_user)

      get statistics_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Estadísticas del álbum")
      expect(response.body).to include("Argentina")
      expect(response.body).to include("10 copias")
      expect(response.body).to include("Brasil")
      expect(response.body).to include("5 faltantes")
    end
  end
end
