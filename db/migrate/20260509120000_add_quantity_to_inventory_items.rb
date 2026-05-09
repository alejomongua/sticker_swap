class AddQuantityToInventoryItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inventory_items, :quantity, :integer, null: false, default: 1
  end
end
