class RenameFwPrefixToFwc < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE stickers
      SET prefix = 'FWC'
      WHERE prefix = 'FW'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE stickers
      SET prefix = 'FW'
      WHERE prefix = 'FWC'
    SQL
  end
end