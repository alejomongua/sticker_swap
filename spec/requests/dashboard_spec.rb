require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /panel" do
    it "filters missing items by prefix and exact code" do
      user = create(:user)
      arg_sticker = create(:sticker, prefix: "ARG", number: 1, name: "Argentina")
      bra_sticker = create(:sticker, prefix: "BRA", number: 2, name: "Brasil")

      create(:inventory_item, user: user, sticker: arg_sticker)
      create(:inventory_item, user: user, sticker: bra_sticker)

      sign_in_as(user)

      get dashboard_path, params: { missing_prefix: "ARG" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Argentina")
      expect(response.body).not_to include("Brasil")

      get dashboard_path, params: { missing_code: "BRA2" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brasil")
      expect(response.body).not_to include("Argentina")
    end

    it "filters duplicate items by prefix and exact code" do
      user = create(:user)
      arg_sticker = create(:sticker, prefix: "ARG", number: 1, name: "Argentina")
      bra_sticker = create(:sticker, prefix: "BRA", number: 2, name: "Brasil")

      create(:inventory_item, :duplicate, user: user, sticker: arg_sticker, quantity: 2)
      create(:inventory_item, :duplicate, user: user, sticker: bra_sticker, quantity: 1)

      sign_in_as(user)

      get dashboard_path, params: { duplicate_prefix: "ARG" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Argentina")
      expect(response.body).not_to include("Brasil")

      get dashboard_path, params: { duplicate_code: "BRA2" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brasil")
      expect(response.body).not_to include("Argentina")
    end

    it "paginates missing items" do
      user = create(:user)

      11.times do |index|
        sticker = create(:sticker, prefix: "ARG", number: index + 1, name: format("Faltante %02d", index + 1))
        create(:inventory_item, user: user, sticker: sticker)
      end

      sign_in_as(user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Faltante 01")
      expect(response.body).not_to include("Faltante 11")
      expect(response.body).to include("Página 1 de 2")

      get dashboard_path, params: { missing_page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Faltante 11")
      expect(response.body).not_to include("Faltante 01")
      expect(response.body).to include("Página 2 de 2")
    end

    it "paginates duplicate items" do
      user = create(:user)

      11.times do |index|
        sticker = create(:sticker, prefix: "ARG", number: index + 1, name: format("Equipo %02d", index + 1))
        create(:inventory_item, :duplicate, user: user, sticker: sticker, quantity: 1)
      end

      sign_in_as(user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Equipo 01")
      expect(response.body).not_to include("Equipo 11")
      expect(response.body).to include("Página 1 de 2")

      get dashboard_path, params: { duplicates_page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Equipo 11")
      expect(response.body).not_to include("Equipo 01")
      expect(response.body).to include("Página 2 de 2")
    end

    it "wires the auto-submit filters and removes filter buttons" do
      user = create(:user)
      sign_in_as(user)

      get dashboard_path

      expect(response.body).to include("inventory-filter")
      expect(response.body).not_to include(">Filtrar<")
    end

    it "shows the completion percentage when missing stickers are loaded" do
      user = create(:user)
      create(:sticker, prefix: "ARG", number: 1)
      create(:sticker, prefix: "ARG", number: 2)
      create(:sticker, prefix: "ARG", number: 3)
      create(:inventory_item, user: user, sticker: Sticker.find_by!(prefix: "ARG", number: 1))

      sign_in_as(user)

      get dashboard_path

      expect(response.body).to include("66.7%")
      expect(response.body).to include("2 de 3 fichas estimadas")
    end
  end
end