class ApplicationController < ActionController::Base
  include Authentication
  helper_method :current_group_admin?, :statistics_available?
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def append_alert(message, now: false)
      return if message.blank?

      existing_message = flash[:alert].presence
      merged_message = [ existing_message, message ].compact.reject { |entry| existing_message.present? && existing_message.include?(entry) && entry == message }.join(" ")
      merged_message = existing_message if merged_message.blank?
      merged_message ||= message

      if now
        flash.now[:alert] = merged_message
      else
        flash[:alert] = merged_message
      end
    end

    def persist_inventory_conflicts(conflicts)
      return if conflicts.blank? || current_user.blank?

      session[:inventory_conflicts_by_user_id] = inventory_conflicts_by_user_id.merge(
        current_user.id.to_s => stored_inventory_conflicts.merge(
          conflicts.index_with do |conflict|
            {
              "previous_status" => conflict.previous_status,
              "new_status" => conflict.new_status
            }
          end.transform_keys { |conflict| conflict.code }
        )
      )
    end

    def inventory_conflicts_alert
      return if stored_inventory_conflicts.empty?

      changes = stored_inventory_conflicts.sort.map do |code, conflict|
        "#{code}: de #{human_inventory_status(conflict["previous_status"])} a #{human_inventory_status(conflict["new_status"])}"
      end

      "Posible incoherencia en tu inventario. Revisa #{changes.join(', ')}."
    end

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

    def inventory_conflicts_by_user_id
      value = session[:inventory_conflicts_by_user_id]
      value.is_a?(Hash) ? value : {}
    end

    def stored_inventory_conflicts
      return {} if current_user.blank?

      conflicts = inventory_conflicts_by_user_id[current_user.id.to_s]
      conflicts.is_a?(Hash) ? conflicts : {}
    end

    def human_inventory_status(status)
      status == "duplicate" ? "repetida" : "faltante"
    end

    def render_dashboard_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace("flash", partial: "shared/flash_frame"),
        turbo_stream.replace("dashboard_panel", partial: "dashboard/panel")
      ], status: status
    end

    def render_missing_table_turbo_stream(status: :ok)
      render turbo_stream: [
        turbo_stream.replace("flash", partial: "shared/flash_frame"),
        turbo_stream.replace("missing_table", partial: "dashboard/missing_table_frame")
      ], status: status
    end

    def turbo_frame_request_id
      request.headers["Turbo-Frame"]
    end
end
