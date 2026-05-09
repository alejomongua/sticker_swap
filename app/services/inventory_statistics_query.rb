class InventoryStatisticsQuery
  Entry = Struct.new(:sticker, :total, keyword_init: true)

  MINIMUM_ELIGIBLE_USERS = 5
  DEFAULT_LIMIT = 10

  class << self
    def available?
      new.eligible_users_count >= MINIMUM_ELIGIBLE_USERS
    end
  end

  def easiest(limit: DEFAULT_LIMIT)
    aggregated_stickers_for(
      InventoryItem.duplicate,
      "SUM(inventory_items.quantity)",
      limit: limit
    )
  end

  def hardest(limit: DEFAULT_LIMIT)
    aggregated_stickers_for(
      InventoryItem.missing,
      "COUNT(inventory_items.id)",
      limit: limit
    )
  end

  def eligible_users_count
    User.where(id: InventoryItem.duplicate.select(:user_id))
        .where(id: InventoryItem.missing.select(:user_id))
        .distinct
        .count
  end

  private
    def aggregated_stickers_for(scope, aggregate_sql, limit:)
      Sticker.joins(:inventory_items)
             .merge(scope)
             .select("stickers.*, #{aggregate_sql} AS aggregate_total")
             .group("stickers.id")
             .order(Arel.sql("aggregate_total DESC"), :group_name, :prefix, :number)
             .limit(limit)
             .map do |sticker|
               Entry.new(sticker: sticker, total: sticker.read_attribute("aggregate_total").to_i)
             end
    end
end