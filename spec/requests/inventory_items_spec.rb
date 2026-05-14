require 'rails_helper'

RSpec.describe 'InventoryItems', type: :request do
  describe 'POST /inventario' do
    it 'imports known sticker codes for the authenticated user' do
      user = create(:user)
      first_sticker = create(:sticker, prefix: 'ZZIM', number: 10_001, name: 'Argentina', group_name: 'Grupo J')
      second_sticker = create(:sticker, prefix: 'ZZIN', number: 10_002, name: 'Brasil', group_name: 'Grupo C')

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'missing', codes: "#{first_sticker.code}\n#{second_sticker.code}" } }
      end.to change(user.inventory_items, :count).by(2)

      expect(response).to redirect_to(dashboard_path)
      expect(user.inventory_items.missing.count).to eq(2)
    end

    it 'shows unknown missing codes as an alert without a success notice' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ZZIA', number: 10_011, name: 'Argentina', group_name: 'Grupo J')

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'missing', codes: "#{sticker.code}\nNOPE99999" } }
      end.to change(user.inventory_items, :count).by(1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).not_to eq('Inventario actualizado.')
      expect(flash[:alert]).to eq('No se encontraron estas fichas faltantes: NOPE99999.')
      expect(user.inventory_items.find_by!(sticker: sticker)).to be_missing
    end

    it 'adds duplicate quantity to an existing repeated sticker' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ZZIB', number: 10_021, name: 'Argentina', group_name: 'Grupo J')
      create(:inventory_item, :duplicate, user: user, sticker: sticker, quantity: 2)

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'duplicate', code: sticker.code, quantity: 3 } }
      end.not_to change(user.inventory_items, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(user.inventory_items.find_by!(sticker: sticker).quantity).to eq(5)
    end

    it 'alerts when a missing sticker is moved to duplicates and keeps the submitted quantity' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ZZIC', number: 10_031, name: 'Argentina', group_name: 'Grupo J')
      create(:inventory_item, user: user, sticker: sticker)

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'duplicate', code: sticker.code, quantity: 2 } }
      end.not_to change(user.inventory_items, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to include("#{sticker.code}: de faltante a repetida")
      item = user.inventory_items.find_by!(sticker: sticker)
      expect(item).to be_duplicate
      expect(item.quantity).to eq(2)
    end

    it 'alerts when a repeated sticker is moved to missing' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ZZID', number: 10_041, name: 'Argentina', group_name: 'Grupo J')
      create(:inventory_item, :duplicate, user: user, sticker: sticker, quantity: 3)

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'missing', codes: sticker.code } }
      end.not_to change(user.inventory_items, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to include("#{sticker.code}: de repetida a faltante")
      item = user.inventory_items.find_by!(sticker: sticker)
      expect(item).to be_missing
      expect(item.quantity).to eq(1)
    end

    it 'imports duplicate codes from bulk input, ignores unknown codes, and counts repeated entries' do
      user = create(:user)
      arg = create(:sticker, prefix: 'ZZIE', number: 10_051, name: 'Argentina', group_name: 'Grupo J')
      bra = create(:sticker, prefix: 'ZZIF', number: 10_052, name: 'Brasil', group_name: 'Grupo C')

      sign_in_as(user)

      expect do
        post inventory_items_path, params: {
          inventory_item: {
            status: 'duplicate',
            codes: "#{arg.code}, #{bra.code} #{arg.code}\nNOPE99999",
            quantity: 1
          }
        }
      end.to change(user.inventory_items, :count).by(2)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to include('No se encontraron: NOPE99999.')
      expect(user.inventory_items.find_by!(sticker: arg).quantity).to eq(2)
      expect(user.inventory_items.find_by!(sticker: bra).quantity).to eq(1)
    end

    it 'rejects invalid duplicate quantity' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ZZIG', number: 10_061, name: 'Argentina', group_name: 'Grupo J')

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'duplicate', code: sticker.code, quantity: 0 } }
      end.not_to change(user.inventory_items, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to eq('La cantidad debe ser un entero mayor a 0.')
    end

    it 'redirects back to missing table when submitted from missing table view' do
      user = create(:user)
       sticker = create(:sticker, prefix: 'ZZIH', number: 10_071, name: 'Argentina', group_name: 'Grupo J')

      sign_in_as(user)

      post inventory_items_path,
         params: { inventory_item: { status: 'missing', codes: sticker.code } },
           headers: { 'HTTP_REFERER' => missing_table_dashboard_url }

      expect(response).to redirect_to(missing_table_dashboard_path)
    end

    it 'redirects back to the missing table with turbo frame requests' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ZZII', number: 10_081, name: 'Argentina', group_name: 'Grupo J')

      sign_in_as(user)

      post inventory_items_path,
           params: { inventory_item: { status: 'missing', codes: sticker.code } },
           headers: {
             'HTTP_REFERER' => missing_table_dashboard_url,
             'ACCEPT' => Mime[:turbo_stream].to_s,
             'Turbo-Frame' => 'missing_table'
           }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('turbo-stream method="morph" action="replace" target="missing_table"')
      expect(response.body).to include('turbo-stream action="replace" target="flash"')
      expect(response.body).to include(sticker.code)
    end
  end

  describe 'POST /inventario/consumir' do
    it 'removes missing items in bulk and reports unknown or already resolved codes' do
      user = create(:user)
      resolved = create(:sticker, prefix: 'ZZCJ', number: 11_001, name: 'Argentina', group_name: 'Grupo J')
      still_missing = create(:sticker, prefix: 'ZZCK', number: 11_002, name: 'Brasil', group_name: 'Grupo C')
      already_resolved = create(:sticker, prefix: 'ZZCL', number: 11_003, name: 'Senegal', group_name: 'Grupo A')

      create(:inventory_item, user: user, sticker: resolved)
      create(:inventory_item, user: user, sticker: still_missing)

      sign_in_as(user)

      expect do
        post consume_inventory_items_path, params: {
          inventory_item: {
            status: 'missing',
            codes: "#{resolved.code}\n#{already_resolved.code}\nNOPE99999"
          }
        }
      end.to change(user.inventory_items, :count).by(-1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('Tus faltantes se actualizaron.')
      expect(flash[:alert]).to include('No se encontraron: NOPE99999.')
      expect(flash[:alert]).to include("Estas fichas no figuraban como faltantes: #{already_resolved.code}.")
      expect(user.inventory_items.find_by(sticker: resolved)).to be_nil
      expect(user.inventory_items.find_by!(sticker: still_missing)).to be_missing
    end

    it 'decrements duplicate quantities in bulk and removes exhausted items' do
      user = create(:user)
      kept_duplicate = create(:sticker, prefix: 'ZZCM', number: 11_011, name: 'Argentina', group_name: 'Grupo J')
      exhausted_duplicate = create(:sticker, prefix: 'ZZCN', number: 11_012, name: 'Brasil', group_name: 'Grupo C')
      not_owned = create(:sticker, prefix: 'ZZCO', number: 11_013, name: 'Senegal', group_name: 'Grupo A')

      create(:inventory_item, :duplicate, user: user, sticker: kept_duplicate, quantity: 3)
      create(:inventory_item, :duplicate, user: user, sticker: exhausted_duplicate, quantity: 1)

      sign_in_as(user)

      expect do
        post consume_inventory_items_path, params: {
          inventory_item: {
            status: 'duplicate',
            codes: "#{kept_duplicate.code}\n#{kept_duplicate.code}\n#{exhausted_duplicate.code}\n#{exhausted_duplicate.code}\n#{not_owned.code}\nNOPE99999"
          }
        }
      end.to change(user.inventory_items, :count).by(-1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('Tus repetidas se descontaron.')
      expect(flash[:alert]).to include('No se encontraron: NOPE99999.')
      expect(flash[:alert]).to include("Estas fichas no estaban en tus repetidas: #{not_owned.code}.")
      expect(flash[:alert]).to include("No tenías suficientes copias para descontar todas las apariciones de: #{exhausted_duplicate.code}.")
      expect(user.inventory_items.find_by!(sticker: kept_duplicate).quantity).to eq(1)
      expect(user.inventory_items.find_by(sticker: exhausted_duplicate)).to be_nil
    end
  end

  describe 'POST /inventario/nuevas' do
    it 'removes missing items first and sends extra copies to duplicates in the same request' do
      user = create(:user)
      missing_sticker = create(:sticker, prefix: 'ZZNP', number: 12_001, name: 'Argentina', group_name: 'Grupo J')
      duplicate_sticker = create(:sticker, prefix: 'ZZNQ', number: 12_002, name: 'Brasil', group_name: 'Grupo C')
      owned_sticker = create(:sticker, prefix: 'ZZNR', number: 12_003, name: 'Senegal', group_name: 'Grupo A')

      create(:inventory_item, user: user, sticker: missing_sticker)
      create(:inventory_item, :duplicate, user: user, sticker: duplicate_sticker, quantity: 2)

      sign_in_as(user)

      expect do
        post add_new_inventory_items_path, params: {
          inventory_item: {
            codes: "#{missing_sticker.code}\n#{missing_sticker.code}\n#{duplicate_sticker.code}\n#{owned_sticker.code}\nNOPE99999"
          }
        }
      end.to change(user.inventory_items, :count).by(1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('Nuevas figuras registradas.')
      expect(flash[:alert]).to eq('No se encontraron: NOPE99999.')
      expect(user.inventory_items.find_by!(sticker: missing_sticker)).to be_duplicate
      expect(user.inventory_items.find_by!(sticker: missing_sticker).quantity).to eq(1)
      expect(user.inventory_items.find_by!(sticker: duplicate_sticker).quantity).to eq(3)
      expect(user.inventory_items.find_by!(sticker: owned_sticker).quantity).to eq(1)
    end
  end

  describe 'PATCH /inventario/:id' do
    it 'updates the quantity for duplicate items' do
      user = create(:user)
      inventory_item = create(:inventory_item, :duplicate, user: user, quantity: 2)

      sign_in_as(user)

      patch inventory_item_path(inventory_item), params: { inventory_item: { quantity: 5 } }

      expect(response).to redirect_to(dashboard_path)
      expect(inventory_item.reload.quantity).to eq(5)
    end

    it 'updates duplicate items asynchronously in the dashboard panel' do
      user = create(:user)
      inventory_item = create(:inventory_item, :duplicate, user: user, quantity: 2)

      sign_in_as(user)

      patch inventory_item_path(inventory_item),
            params: { inventory_item: { quantity: 5 } },
            headers: {
              'HTTP_REFERER' => dashboard_url,
              'ACCEPT' => Mime[:turbo_stream].to_s,
              'Turbo-Frame' => 'dashboard_panel'
            }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('turbo-stream method="morph" action="replace" target="dashboard_panel"')
      expect(response.body).to include('turbo-stream action="replace" target="flash"')
      expect(response.body).to include('La cantidad de repetidas se actualizó.')
      expect(inventory_item.reload.quantity).to eq(5)
    end

    it 'preserves duplicate filters after an async quantity update' do
      user = create(:user)
      target_item = create(:inventory_item, :duplicate, user: user, quantity: 2,
                           sticker: create(:sticker, prefix: 'ZZPF', number: 70_001, name: 'Argentina'))
      other_item = create(:inventory_item, :duplicate, user: user, quantity: 1,
                          sticker: create(:sticker, prefix: 'ZZPG', number: 70_002, name: 'Brasil'))

      sign_in_as(user)

      patch inventory_item_path(target_item),
            params: {
              inventory_item: { quantity: 5 },
              duplicate_mode: 'single',
              duplicate_code: target_item.code,
              missing_page: 1
            },
            headers: {
              'HTTP_REFERER' => dashboard_url,
              'ACCEPT' => Mime[:turbo_stream].to_s,
              'Turbo-Frame' => 'dashboard_panel'
            }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="duplicate_code" id="duplicate_code" value="#{target_item.code}"))
      expect(response.body).to include(target_item.code)
      expect(response.body).not_to include(other_item.code)
    end

    it 'removes duplicate items when the quantity is set to zero' do
      user = create(:user)
      inventory_item = create(:inventory_item, :duplicate, user: user, quantity: 2)

      sign_in_as(user)

      expect do
        patch inventory_item_path(inventory_item), params: { inventory_item: { quantity: 0 } }
      end.to change(user.inventory_items, :count).by(-1)

      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe 'DELETE /inventario/:id' do
    it 'removes missing items asynchronously in the dashboard panel' do
      user = create(:user)
      inventory_item = create(:inventory_item, user: user)

      sign_in_as(user)

      expect do
        delete inventory_item_path(inventory_item), headers: {
          'HTTP_REFERER' => dashboard_url,
          'ACCEPT' => Mime[:turbo_stream].to_s,
          'Turbo-Frame' => 'dashboard_panel'
        }
      end.to change(user.inventory_items, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('turbo-stream method="morph" action="replace" target="dashboard_panel"')
      expect(response.body).to include('La figura ya no figura como faltante.')
    end

    it 'preserves missing filters after an async remove action' do
      user = create(:user)
      target_item = create(:inventory_item, user: user,
                           sticker: create(:sticker, prefix: 'ZZPH', number: 70_011, name: 'Argentina'))
      other_item = create(:inventory_item, user: user,
                          sticker: create(:sticker, prefix: 'ZZPI', number: 70_012, name: 'Brasil'))

      sign_in_as(user)

      delete inventory_item_path(target_item),
             params: {
               duplicate_mode: 'single',
               missing_code: target_item.code,
               duplicates_page: 1
             },
             headers: {
               'HTTP_REFERER' => dashboard_url,
               'ACCEPT' => Mime[:turbo_stream].to_s,
               'Turbo-Frame' => 'dashboard_panel'
             }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="missing_code" id="missing_code" value="#{target_item.code}"))
      expect(response.body).to include('No hay faltantes que coincidan con ese filtro.')
      expect(response.body).not_to include(other_item.code)
    end
  end
end
