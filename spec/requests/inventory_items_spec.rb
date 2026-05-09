require 'rails_helper'

RSpec.describe 'InventoryItems', type: :request do
  describe 'POST /inventario' do
    it 'imports known sticker codes for the authenticated user' do
      user = create(:user)
      create(:sticker, prefix: 'ARG', number: 1, name: 'Argentina', group_name: 'Grupo J')
      create(:sticker, prefix: 'BRA', number: 2, name: 'Brasil', group_name: 'Grupo C')

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'missing', codes: "ARG1\nBRA2" } }
      end.to change(user.inventory_items, :count).by(2)

      expect(response).to redirect_to(dashboard_path)
      expect(user.inventory_items.missing.count).to eq(2)
    end

    it 'adds duplicate quantity to an existing repeated sticker' do
      user = create(:user)
      sticker = create(:sticker, prefix: 'ARG', number: 1, name: 'Argentina', group_name: 'Grupo J')
      create(:inventory_item, :duplicate, user: user, sticker: sticker, quantity: 2)

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'duplicate', code: 'ARG1', quantity: 3 } }
      end.not_to change(user.inventory_items, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(user.inventory_items.find_by!(sticker: sticker).quantity).to eq(5)
    end

    it 'rejects invalid duplicate quantity' do
      user = create(:user)
      create(:sticker, prefix: 'ARG', number: 1, name: 'Argentina', group_name: 'Grupo J')

      sign_in_as(user)

      expect do
        post inventory_items_path, params: { inventory_item: { status: 'duplicate', code: 'ARG1', quantity: 0 } }
      end.not_to change(user.inventory_items, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to eq('La cantidad debe ser un entero mayor a 0.')
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
