require "rails_helper"

RSpec.describe "Progress", type: :request do
  describe "GET /progreso" do
    it "shows the overall percentage and the per-prefix breakdown" do
      user = create(:user)
      arg_1 = create(:sticker, prefix: "ARG", number: 1, name: "Argentina", group_name: "Grupo J")
      create(:sticker, prefix: "ARG", number: 2, name: "Argentina", group_name: "Grupo J")
      create(:sticker, prefix: "ARG", number: 3, name: "Argentina", group_name: "Grupo J")
      create(:sticker, prefix: "BRA", number: 1, name: "Brasil", group_name: "Grupo C")
      bra_2 = create(:sticker, prefix: "BRA", number: 2, name: "Brasil", group_name: "Grupo C")

      create(:inventory_item, user: user, sticker: arg_1)
      create(:inventory_item, user: user, sticker: bra_2)

      sign_in_as(user)

      get progress_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Progreso")
      expect(response.body).to include("60.0%")
      expect(response.body).to include("3 de 5 fichas estimadas")
      expect(response.body).to include("ARG")
      expect(response.body).to include("66.7%")
      expect(response.body).to include("BRA")
      expect(response.body).to include("50.0%")
    end

    it "shows the clicked group detail with owned and missing stickers" do
      user = create(:user)
      arg_1 = create(:sticker, prefix: "ARG", number: 1, name: "Argentina", group_name: "Grupo J")
      arg_2 = create(:sticker, prefix: "ARG", number: 2, name: "Argentina", group_name: "Grupo J")

      create(:inventory_item, user: user, sticker: arg_1)

      sign_in_as(user)

      get progress_path(group: "ARG")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Detalle de ARG")
      expect(response.body).to include("Las tienes")
      expect(response.body).to include("Te faltan")
      expect(response.body).to include(arg_2.code)
    end

    it "counts sticker 00 inside the FWC group in the progress view" do
      user = create(:user)
      sticker_00 = create(:sticker, prefix: "", number: 0, name: "Fifa", group_name: "Specials")
      fwc_1 = create(:sticker, prefix: "FWC", number: 1, name: "Fifa", group_name: "Specials")
      create(:sticker, prefix: "FWC", number: 2, name: "Fifa", group_name: "Specials")

      create(:inventory_item, user: user, sticker: sticker_00)
      create(:inventory_item, user: user, sticker: fwc_1)

      sign_in_as(user)

      get progress_path(group: "FWC")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FWC")
      expect(response.body).to include("33.3%")
      expect(response.body).to include("00")
      expect(response.body).to include("FWC1")
    end

    it "shows a clean empty state when there are no missing stickers loaded" do
      user = create(:user)
      create(:sticker, prefix: "ARG", number: 1, name: "Argentina", group_name: "Grupo J")

      sign_in_as(user)

      get progress_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agrega faltantes en el panel para calcular tu avance total")
      expect(response.body).to include("Todavía no hay detalle disponible")
    end

    it "adds the progress entry to the authenticated navigation" do
      user = create(:user)
      sign_in_as(user)

      get dashboard_path

      expect(response.body).to include(">Progreso<")
    end
  end
end