class ApplicationController < ActionController::Base
  include Authentication
  helper_method :statistics_available?
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def statistics_available?
      @statistics_available ||= InventoryStatisticsQuery.available?
    end

    def current_page_title
      "StickerSwap"
    end
end
