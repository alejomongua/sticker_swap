class DashboardController < ApplicationController
  DUPLICATES_PER_PAGE = 10
  MISSING_ITEMS_PER_PAGE = 10

  before_action :prepare_missing_table_data, only: :missing_table

  def show
    progress_query = InventoryProgressQuery.new(current_user)

    @duplicate_mode = duplicate_mode_param
    @duplicate_prefix = params[:duplicate_prefix].to_s.strip.upcase.presence
    @duplicate_code = normalized_code_param(params[:duplicate_code])
    @missing_prefix = params[:missing_prefix].to_s.strip.upcase.presence
    @missing_code = normalized_code_param(params[:missing_code])
    @duplicate_filters = {
      duplicate_prefix: @duplicate_prefix,
      duplicate_code: @duplicate_code,
      duplicate_mode: @duplicate_mode
    }.compact_blank
    @missing_filters = {
      missing_prefix: @missing_prefix,
      missing_code: @missing_code,
      duplicate_mode: @duplicate_mode
    }.compact_blank
    @dashboard_filters = @duplicate_filters.merge(@missing_filters)

    filtered_duplicate_items = duplicate_items_scope
    filtered_missing_items = missing_items_scope

    @duplicate_items_count = filtered_duplicate_items.count
    @duplicate_pages = [ (@duplicate_items_count.to_f / DUPLICATES_PER_PAGE).ceil, 1 ].max
    @duplicate_page = duplicate_page_param(@duplicate_pages)
    @duplicate_items = filtered_duplicate_items.offset((@duplicate_page - 1) * DUPLICATES_PER_PAGE).limit(DUPLICATES_PER_PAGE)

    @missing_items_count = filtered_missing_items.count
    @missing_pages = [ (@missing_items_count.to_f / MISSING_ITEMS_PER_PAGE).ceil, 1 ].max
    @missing_page = missing_page_param(@missing_pages)
    @missing_items = filtered_missing_items.offset((@missing_page - 1) * MISSING_ITEMS_PER_PAGE).limit(MISSING_ITEMS_PER_PAGE)

    @duplicate_copies_count = current_user.inventory_items.duplicate.sum(:quantity)
    @missing_total_count = current_user.inventory_items.missing.count
    @duplicate_prefixes = sorted_prefixes_for(current_user.inventory_items.duplicate)
    @missing_prefixes = sorted_prefixes_for(current_user.inventory_items.missing)
    @progress_summary = progress_query.summary
    append_alert(inventory_conflicts_alert, now: true)
  end

  def missing_table
    @duplicate_mode = duplicate_mode_param
    @missing_total_count = current_user.inventory_items.missing.count
  end

  private
    def duplicate_items_scope
      filtered_items_scope(current_user.duplicate_items, prefix: @duplicate_prefix, code: params[:duplicate_code])
    end

    def missing_items_scope
      filtered_items_scope(current_user.missing_items, prefix: @missing_prefix, code: params[:missing_code])
    end

    def filtered_items_scope(scope, prefix:, code:)
      filtered_scope = scope
      filtered_scope = filtered_scope.where(stickers: { prefix: prefix }).references(:sticker) if prefix.present?

      return filtered_scope if code.blank?

      parsed_prefix, number = Sticker.split_code(code)
      return filtered_scope.none if number.nil?

      filtered_scope.where(stickers: { prefix: parsed_prefix.to_s, number: number }).references(:sticker)
    end

    def duplicate_mode_param
      params[:duplicate_mode].to_s == "bulk" ? "bulk" : "single"
    end

    def duplicate_page_param(total_pages)
      page = Integer(params[:duplicates_page], exception: false)
      page = 1 if page.nil? || page < 1
      [ page, total_pages ].min
    end

    def missing_page_param(total_pages)
      page = Integer(params[:missing_page], exception: false)
      page = 1 if page.nil? || page < 1
      [ page, total_pages ].min
    end

    def normalized_code_param(raw_value)
      raw_code = raw_value.to_s.strip
      return if raw_code.empty?

      prefix, number = Sticker.split_code(raw_code)
      return raw_code.upcase if number.nil?

      prefix.present? ? "#{prefix}#{number}" : format("%02d", number)
    end

    def prepare_missing_table_data
      @missing_items_by_sticker_id = current_user.missing_items.includes(:sticker).index_by(&:sticker_id)
      @stickers_by_prefix = Sticker.catalog_order.group_by(&:prefix)
    end

    def sorted_prefixes_for(scope)
      Sticker.sorted_prefixes(scope.joins(:sticker).distinct.pluck("stickers.prefix"))
    end
end
