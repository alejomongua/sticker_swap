require 'rails_helper'

RSpec.describe 'Manual', type: :request do
  describe 'GET /manual' do
    it 'is publicly accessible and explains the main user flows' do
      get manual_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Cómo usar StickerSwap')
      expect(response.body).to include('código de invitación')
      expect(response.body).to include('grupo activo')
      expect(response.body).to include('Grupos')
      expect(response.body).to include('Movimientos rápidos')
      expect(response.body).to include('Importar / exportar')
      expect(response.body).to include('figuritas.app')
      expect(response.body).to include('Progreso')
      expect(response.body).to include('Estadísticas')
      expect(response.body).to include('intercambio físico')
      expect(response.body).to include('https://github.com/alejomongua/sticker_swap')
      expect(response.body).to include('Sin el patrocinio de: FIFA, Panini, Coca-Cola.')
    end
  end

  describe 'GET /sesion' do
    it 'shows a link to the manual in the public navigation' do
      get new_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('>Manual<')
    end
  end
end
