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
      expect(flash[:notice]).to be_nil
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
             'Turbo-Frame' => 'missing_table'
           }

      expect(response).to redirect_to(missing_table_dashboard_path)
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
end
