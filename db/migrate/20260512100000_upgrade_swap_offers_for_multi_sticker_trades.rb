class UpgradeSwapOffersForMultiStickerTrades < ActiveRecord::Migration[8.1]
  def up
    add_column :swap_offers, :offered_sticker_ids, :integer, array: true, default: [], null: false
    add_column :swap_offers, :requested_sticker_ids, :integer, array: true, default: [], null: false
    add_reference :swap_offers, :countered_from, foreign_key: { to_table: :swap_offers }, index: true

    execute <<~SQL.squish
      UPDATE swap_offers
      SET offered_sticker_ids = ARRAY[offered_sticker_id],
          requested_sticker_ids = ARRAY[requested_sticker_id]
    SQL

    remove_foreign_key :swap_offers, column: :offered_sticker_id
    remove_foreign_key :swap_offers, column: :requested_sticker_id
    remove_index :swap_offers, :offered_sticker_id
    remove_index :swap_offers, :requested_sticker_id
    remove_column :swap_offers, :offered_sticker_id
    remove_column :swap_offers, :requested_sticker_id
  end

  def down
    add_reference :swap_offers, :offered_sticker, null: false, foreign_key: { to_table: :stickers }
    add_reference :swap_offers, :requested_sticker, null: false, foreign_key: { to_table: :stickers }

    execute <<~SQL.squish
      UPDATE swap_offers
      SET offered_sticker_id = offered_sticker_ids[1],
          requested_sticker_id = requested_sticker_ids[1]
    SQL

    remove_reference :swap_offers, :countered_from, foreign_key: { to_table: :swap_offers }, index: true
    remove_column :swap_offers, :offered_sticker_ids
    remove_column :swap_offers, :requested_sticker_ids
  end
end
