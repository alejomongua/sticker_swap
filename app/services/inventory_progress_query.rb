require "set"

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

  Detail = Struct.new(
    :entry,
    :owned_stickers,
    :missing_stickers,
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
    @entries ||= grouped_catalog.map do |group_code, stickers|
      build_entry(group_code, stickers)
    end
  end

  def detail_for(group_code)
    normalized_code = normalize_group_code(group_code)
    return if normalized_code.nil?

    stickers = grouped_catalog.to_h[normalized_code]
    return if stickers.blank?

    Detail.new(
      entry: build_entry(normalized_code, stickers),
      owned_stickers: stickers.reject { |sticker| missing_sticker_ids.include?(sticker.id) },
      missing_stickers: stickers.select { |sticker| missing_sticker_ids.include?(sticker.id) }
    )
  end

  private
    attr_reader :user

    def catalog_stickers
      @catalog_stickers ||= Sticker.catalog_order.to_a
    end

    def grouped_catalog
      @grouped_catalog ||= catalog_stickers.each_with_object({}) do |sticker, groups|
        group_code = group_code_for(sticker)
        groups[group_code] ||= []
        groups[group_code] << sticker
      end
    end

    def build_entry(group_code, stickers)
      sample = stickers.first
      total_count = stickers.size
      missing_count = stickers.count { |sticker| missing_sticker_ids.include?(sticker.id) }
      owned_count = [ total_count - missing_count, 0 ].max

      Entry.new(
        code: group_code,
        label: label_for(stickers),
        group_name: sample.group_name,
        total_count: total_count,
        missing_count: missing_count,
        owned_count: owned_count,
        completion_percentage: summary.tracked? ? percentage_for(owned_count, total_count) : nil
      )
    end

    def missing_sticker_ids
      @missing_sticker_ids ||= missing_items_relation.pluck(:sticker_id).to_set
    end

    def missing_items_relation
      @missing_items_relation ||= user.inventory_items.missing
    end

    def group_code_for(sticker)
      return "FWC" if sticker.number.zero? && sticker.prefix.blank?

      sticker.prefix.presence || sticker.code
    end

    def label_for(stickers)
      unique_names = stickers.map(&:name).compact_blank.uniq
      return unique_names.first if unique_names.one?

      stickers.first.group_name.presence || stickers.first.code
    end

    def normalize_group_code(group_code)
      group_code.to_s.strip.upcase.presence
    end

    def tracked?(missing_count, catalog_count)
      missing_count.positive? && catalog_count.positive?
    end

    def percentage_for(numerator, denominator)
      return 0.0 if denominator.zero?

      ((numerator.to_f / denominator) * 100).round(1)
    end
end
