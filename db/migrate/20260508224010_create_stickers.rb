class CreateStickers < ActiveRecord::Migration[8.1]
  def change
    create_table :stickers do |t|
      t.string :prefix, null: false, default: ""
      t.integer :number, null: false
      t.string :name
      t.string :photo
      t.string :group_name, null: false, default: ""

      t.timestamps
    end

    add_index :stickers, %i[ prefix number ], unique: true
    add_index :stickers, :group_name
  end
end
