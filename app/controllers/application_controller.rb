class ApplicationController < ActionController::Base
  include Authentication
  helper_method :current_group_admin?, :statistics_available?
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def require_current_group!
      return if current_group.present?

      redirect_to groups_path, alert: "Únete a un grupo o crea uno para usar esta sección."
    end

    def statistics_available?
      @statistics_available ||= current_group.present? && InventoryStatisticsQuery.available?(group: current_group)
    end

    def current_group_admin?
      current_group.present? && current_user.admin_of?(current_group)
    end

    def current_page_title
      "StickerSwap"
    end
end
