require 'rails_helper'

RSpec.describe InventoryItem, type: :model do
  it 'does not allow duplicated user and sticker combinations' do
    create(:inventory_item)
    repeated_item = build(:inventory_item, user: InventoryItem.first.user, sticker: InventoryItem.first.sticker)

    expect(repeated_item).not_to be_valid
    expect(repeated_item.errors[:sticker_id]).to include('ya está cargada en tu inventario')
  end

  it 'keeps missing items at quantity one' do
    inventory_item = build(:inventory_item, quantity: 4)

    expect(inventory_item).to be_valid
    expect(inventory_item.quantity).to eq(1)
  end

  it 'requires positive quantity for duplicate items' do
    inventory_item = build(:inventory_item, :duplicate, quantity: 0)

    expect(inventory_item).not_to be_valid
    expect(inventory_item.errors[:quantity]).to include('must be greater than 0')
  end

  describe '#consume_one!' do
    it 'decrements duplicate items with more than one copy' do
      inventory_item = create(:inventory_item, :duplicate, quantity: 3)

      expect { inventory_item.consume_one! }.not_to change(described_class, :count)
      expect(inventory_item.reload.quantity).to eq(2)
    end

    it 'removes duplicate items when the last copy is consumed' do
      inventory_item = create(:inventory_item, :duplicate, quantity: 1)

      expect { inventory_item.consume_one! }.to change(described_class, :count).by(-1)
    end
  end
end
