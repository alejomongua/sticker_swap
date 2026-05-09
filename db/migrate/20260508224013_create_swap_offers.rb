class CreateSwapOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :swap_offers do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :receiver, null: false, foreign_key: { to_table: :users }
      t.references :offered_sticker, null: false, foreign_key: { to_table: :stickers }
      t.references :requested_sticker, null: false, foreign_key: { to_table: :stickers }
      t.datetime :responded_at
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :swap_offers, %i[ receiver_id status ]
    add_index :swap_offers, %i[ sender_id status ]
  end
end
