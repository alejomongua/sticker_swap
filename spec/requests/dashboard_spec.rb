require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /panel" do
    it "orders the prefix filters using the configured catalog sequence" do
      user = create(:user)
      pan = create(:sticker, prefix: "PAN", number: 90_002, name: "Panama")
      arg = create(:sticker, prefix: "ARG", number: 90_001, name: "Argentina")
      mex = create(:sticker, prefix: "MEX", number: 90_003, name: "Mexico")
      fwc = create(:sticker, prefix: "FWC", number: 90_004, name: "Mascota")

      create(:inventory_item, user: user, sticker: pan)
      create(:inventory_item, user: user, sticker: arg)
      create(:inventory_item, user: user, sticker: mex)
      create(:inventory_item, user: user, sticker: fwc)

      sign_in_as(user)

      get dashboard_path

      fwc_index = response.body.index(%(<option value="FWC">FWC</option>))
      mex_index = response.body.index(%(<option value="MEX">MEX</option>))
      arg_index = response.body.index(%(<option value="ARG">ARG</option>))
      pan_index = response.body.index(%(<option value="PAN">PAN</option>))

      expect(fwc_index).to be < mex_index
      expect(mex_index).to be < arg_index
      expect(arg_index).to be < pan_index
    end

    it "includes a full-page link to the interactive missing table" do
      user = create(:user)
      sign_in_as(user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(missing_table_dashboard_path)
      expect(response.body).to include('data-turbo="false"')
    end

    it "filters asynchronously with turbo streams" do
      user = create(:user)
      arg_sticker = create(:sticker, prefix: "ZZTA", number: 50_001, name: "Argentina")
      bra_sticker = create(:sticker, prefix: "ZZTB", number: 50_002, name: "Brasil")

      create(:inventory_item, user: user, sticker: arg_sticker)
      create(:inventory_item, user: user, sticker: bra_sticker)

      sign_in_as(user)

      get dashboard_path,
          params: { missing_prefix: "ZZTA" },
          headers: { "ACCEPT" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('turbo-stream action="replace" target="dashboard_panel"')
      expect(response.body).to include('turbo-stream action="replace" target="flash"')
      expect(response.body).to include("Argentina")
      expect(response.body).not_to include("Brasil")
    end

    it "renders bulk forms for resolved missing stickers and consumed duplicates" do
      user = create(:user)
      sign_in_as(user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Registrar conseguidas")
      expect(response.body).to include("Registrar repetidas cambiadas")
      expect(response.body).to include("Quitar de faltantes")
      expect(response.body).to include("Descontar repetidas")
      expect(response.body).to include(consume_inventory_items_path)
    end

    it "filters missing items by prefix and exact code" do
      user = create(:user)
      arg_sticker = create(:sticker, prefix: "ZZMA", number: 10_001, name: "Argentina")
      bra_sticker = create(:sticker, prefix: "ZZMB", number: 10_002, name: "Brasil")

      create(:inventory_item, user: user, sticker: arg_sticker)
      create(:inventory_item, user: user, sticker: bra_sticker)

      sign_in_as(user)

      get dashboard_path, params: { missing_prefix: "ZZMA" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Argentina")
      expect(response.body).not_to include("Brasil")

      get dashboard_path, params: { missing_code: bra_sticker.code }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brasil")
      expect(response.body).not_to include("Argentina")
    end

    it "filters duplicate items by prefix and exact code" do
      user = create(:user)
      arg_sticker = create(:sticker, prefix: "ZZDA", number: 10_011, name: "Argentina")
      bra_sticker = create(:sticker, prefix: "ZZDB", number: 10_012, name: "Brasil")

      create(:inventory_item, :duplicate, user: user, sticker: arg_sticker, quantity: 2)
      create(:inventory_item, :duplicate, user: user, sticker: bra_sticker, quantity: 1)

      sign_in_as(user)

      get dashboard_path, params: { duplicate_prefix: "ZZDA" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Argentina")
      expect(response.body).not_to include("Brasil")

      get dashboard_path, params: { duplicate_code: bra_sticker.code }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Brasil")
      expect(response.body).not_to include("Argentina")
    end

    it "paginates missing items" do
      user = create(:user)

      11.times do |index|
        sticker = create(:sticker, prefix: "ZZPM", number: 20_000 + index + 1, name: format("Faltante %02d", index + 1))
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
        sticker = create(:sticker, prefix: "ZZPD", number: 21_000 + index + 1, name: format("Equipo %02d", index + 1))
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
      first_sticker = create(:sticker, prefix: "ZZPC", number: 30_001)
      create(:sticker, prefix: "ZZPC", number: 30_002)
      create(:sticker, prefix: "ZZPC", number: 30_003)
      create(:inventory_item, user: user, sticker: first_sticker)
      catalog_count = Sticker.count
      expected_owned_count = catalog_count - 1
      expected_percentage = ((expected_owned_count.to_f / catalog_count) * 100).round(1)

      sign_in_as(user)

      get dashboard_path

      expect(response.body).to include("#{expected_percentage}%")
      expect(response.body).to include("#{expected_owned_count} de #{catalog_count} fichas estimadas")
    end

    it "shows incoherence alerts on every dashboard load after they are detected" do
      user = create(:user)
      sticker = create(:sticker, prefix: "ZZPI", number: 30_011, name: "Argentina")
      create(:inventory_item, user: user, sticker: sticker)

      sign_in_as(user)

      post inventory_items_path, params: { inventory_item: { status: "duplicate", code: sticker.code, quantity: 2 } }

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Posible incoherencia en tu inventario")
      expect(response.body).to include("#{sticker.code}: de faltante a repetida")

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Posible incoherencia en tu inventario")
      expect(response.body).to include("#{sticker.code}: de faltante a repetida")
    end
  end

  describe "GET /panel/faltantes-tabla" do
    it "renders the interactive missing table page" do
      user = create(:user)
      sticker = create(:sticker, prefix: "ZZMT", number: 40_001, name: "Argentina")
      create(:inventory_item, user: user, sticker: sticker)

      sign_in_as(user)

      get missing_table_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tabla interactiva de faltantes")
      expect(response.body).to include(sticker.code)
      expect(response.body).to include('<turbo-frame id="missing_table">')
      expect(response.body).to include('data-turbo-frame="missing_table"')
    end
  end
end
