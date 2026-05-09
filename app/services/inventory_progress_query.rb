class InventoryProgressQuery
  Summary = Struct.new(
    :catalog_stickers_count,
    :missing_items_count,
    :owned_stickers_count,
    :completion_percentage,
    keyword_init: true
  ) do
    def tracked?
      !completion_percentage.nil?
    end
  end

  Entry = Struct.new(
    :code,
    :label,
    :group_name,
    :total_count,
    :missing_count,
    :owned_count,
    :completion_percentage,
    keyword_init: true
  )

  def initialize(user)
    @user = user
  end

  def summary
    @summary ||= begin
      missing_count = missing_items_relation.count
      catalog_count = catalog_stickers.count
      owned_count = [ catalog_count - missing_count, 0 ].max

      Summary.new(
        catalog_stickers_count: catalog_count,
        missing_items_count: missing_count,
        owned_stickers_count: owned_count,
        completion_percentage: tracked?(missing_count, catalog_count) ? percentage_for(owned_count, catalog_count) : nil
      )
    end
  end

  def entries
    @entries ||= grouped_catalog.map do |prefix, stickers|
      sample = stickers.first
      total_count = stickers.size
      missing_count = missing_counts_by_prefix.fetch(prefix, 0)
      owned_count = [ total_count - missing_count, 0 ].max

      Entry.new(
        code: sample.prefix.presence || sample.code,
        label: sample.name.presence || sample.group_name.presence || sample.code,
        group_name: sample.group_name,
        total_count: total_count,
        missing_count: missing_count,
        owned_count: owned_count,
        completion_percentage: summary.tracked? ? percentage_for(owned_count, total_count) : nil
      )
    end
  end

  private
    attr_reader :user

    def catalog_stickers
      @catalog_stickers ||= Sticker.catalog_order.to_a
    end

    def grouped_catalog
      @grouped_catalog ||= catalog_stickers.group_by(&:prefix)
    end

    def missing_counts_by_prefix
      @missing_counts_by_prefix ||= missing_items_relation.joins(:sticker).group("stickers.prefix").count
    end

    def missing_items_relation
      @missing_items_relation ||= user.inventory_items.missing
    end

    def tracked?(missing_count, catalog_count)
      missing_count.positive? && catalog_count.positive?
    end

    def percentage_for(numerator, denominator)
      return 0.0 if denominator.zero?

      ((numerator.to_f / denominator) * 100).round(1)
    end
end