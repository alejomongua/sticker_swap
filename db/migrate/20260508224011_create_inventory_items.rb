class CreateInventoryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sticker, null: false, foreign_key: true
      t.integer :status, null: false

      t.timestamps
    end

    add_index :inventory_items, %i[ user_id sticker_id ], unique: true
    add_index :inventory_items, %i[ user_id status ]
  end
end
