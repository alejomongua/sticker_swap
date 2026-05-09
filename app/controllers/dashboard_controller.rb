class DashboardController < ApplicationController
  DUPLICATES_PER_PAGE = 10

  def show
    progress_query = InventoryProgressQuery.new(current_user)

    @duplicate_items = current_user.duplicate_items
    @missing_items = current_user.missing_items
    @duplicate_mode = duplicate_mode_param
    @duplicate_prefix = params[:duplicate_prefix].to_s.strip.upcase.presence
    @duplicate_code = normalized_duplicate_code
    @duplicate_filters = {
      duplicate_prefix: @duplicate_prefix,
      duplicate_code: @duplicate_code,
      duplicate_mode: @duplicate_mode
    }.compact_blank

    filtered_duplicate_items = duplicate_items_scope

    @duplicate_items_count = filtered_duplicate_items.count
    @duplicate_pages = [ (@duplicate_items_count.to_f / DUPLICATES_PER_PAGE).ceil, 1 ].max
    @duplicate_page = duplicate_page_param(@duplicate_pages)
    @duplicate_items = filtered_duplicate_items.offset((@duplicate_page - 1) * DUPLICATES_PER_PAGE).limit(DUPLICATES_PER_PAGE)
    @duplicate_copies_count = current_user.inventory_items.duplicate.sum(:quantity)
    @duplicate_prefixes = current_user.inventory_items.duplicate.joins(:sticker)
                                      .distinct
                                      .order("stickers.prefix ASC")
                                      .pluck("stickers.prefix")
    @progress_summary = progress_query.summary
  end

  private
    def duplicate_items_scope
      scope = current_user.duplicate_items
      scope = scope.where(stickers: { prefix: @duplicate_prefix }).references(:sticker) if @duplicate_prefix.present?

      return scope unless params[:duplicate_code].present?

      prefix, number = Sticker.split_code(params[:duplicate_code])
      return scope.none if number.nil?

      scope.where(stickers: { prefix: prefix, number: number }).references(:sticker)
    end

    def duplicate_mode_param
      params[:duplicate_mode].to_s == "bulk" ? "bulk" : "single"
    end

    def duplicate_page_param(total_pages)
      page = Integer(params[:duplicates_page], exception: false)
      page = 1 if page.nil? || page < 1
      [ page, total_pages ].min
    end

    def normalized_duplicate_code
      raw_code = params[:duplicate_code].to_s.strip
      return if raw_code.empty?

      prefix, number = Sticker.split_code(raw_code)
      return raw_code.upcase if number.nil?

      "#{prefix}#{number}"
    end
end
