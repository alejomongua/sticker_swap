class InventoryItemsController < ApplicationController
  include DashboardState

  def create
    status = inventory_item_params[:status]
    result = InventoryBulkUpsert.new(
      user: current_user,
      status: status,
      codes: submitted_codes,
      quantity: inventory_item_params[:quantity]
    ).call

    if result.success?
      set_notice(success_message_for(result, status: status))
      append_inventory_alert(unknown_codes_message_for(result, status: status))
      persist_inventory_conflicts(result.conflicts)
      append_inventory_alert(inventory_conflicts_alert) if result.conflicts.any?

      respond_after_inventory_change(redirect_params: { duplicate_mode: params[:duplicate_mode] })
    else
      respond_after_inventory_failure(result.error_message, redirect_params: { duplicate_mode: params[:duplicate_mode] })
    end
  end

  def consume
    status = inventory_item_params[:status]
    result = InventoryBulkConsume.new(
      user: current_user,
      status: status,
      codes: inventory_item_params[:codes]
    ).call

    if result.success?
      set_notice(consume_success_message_for(result, status: status))
      append_inventory_alert(consume_unknown_codes_message_for(result))
      append_inventory_alert(consume_unavailable_codes_message_for(result, status: status))
      append_inventory_alert(consume_insufficient_codes_message_for(result))

      respond_after_inventory_change
    else
      respond_after_inventory_failure(result.error_message)
    end
  end

  def update
    inventory_item = current_user.inventory_items.find(params[:id])

    return respond_after_inventory_failure("Solo puedes ajustar la cantidad de tus repetidas.") unless inventory_item.duplicate?

    quantity = Integer(update_params[:quantity], exception: false)
    return respond_after_inventory_failure("La cantidad debe ser un entero de 0 o más.") if quantity.nil? || quantity.negative?

    if quantity.zero?
      inventory_item.destroy!
      set_notice("La repetida se quitó de tu inventario.")
      respond_after_inventory_change
    else
      inventory_item.update!(quantity: quantity)
      set_notice("La cantidad de repetidas se actualizó.")
      respond_after_inventory_change
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_after_inventory_failure(error.record.errors.full_messages.to_sentence)
  end

  def destroy
    inventory_item = current_user.inventory_items.find(params[:id])
    notice = inventory_item.missing? ? "La figura ya no figura como faltante." : "La figura se quitó de tus repetidas."

    inventory_item.destroy!
    set_notice(notice)
    respond_after_inventory_change(destroy_action: true)
  end

  private
    def inventory_item_params
      params.require(:inventory_item).permit(:code, :codes, :quantity, :status)
    end

    def submitted_codes
      return inventory_item_params[:codes].presence || inventory_item_params[:code] if inventory_item_params[:status] == "duplicate"

      inventory_item_params[:codes]
    end

    def update_params
      params.require(:inventory_item).permit(:quantity)
    end

    def set_notice(message)
      return if message.blank?

      if request.format.turbo_stream?
        flash.now[:notice] = message
      else
        flash[:notice] = message
      end
    end

    def append_inventory_alert(message)
      append_alert(message, now: request.format.turbo_stream?)
    end

    def respond_after_inventory_change(redirect_params: {}, destroy_action: false)
      return render_inventory_turbo_stream if request.format.turbo_stream?

      if destroy_action
        redirect_back fallback_location: dashboard_path, notice: flash[:notice], status: :see_other
      else
        redirect_to dashboard_return_location(redirect_params), status: :see_other
      end
    end

    def respond_after_inventory_failure(message, redirect_params: {})
      return redirect_to(dashboard_return_location(redirect_params), alert: message, status: :see_other) unless request.format.turbo_stream?

      append_alert(message, now: true)
      render_inventory_turbo_stream(status: :unprocessable_entity)
    end

    def render_inventory_turbo_stream(status: :ok)
      state_params = dashboard_query_params_from(request.referer)
                       .merge(submitted_dashboard_state_params)
                       .compact_blank
      set_dashboard_state_params(state_params)

      if turbo_frame_request_id == "missing_table"
        prepare_missing_table_state
        render_missing_table_turbo_stream(status: status)
      else
        prepare_dashboard_state
        render_dashboard_turbo_stream(status: status)
      end
    end

    def dashboard_return_location(extra_params = {})
      referer = request.referer.to_s
      uri = URI.parse(referer)
      query_params = dashboard_query_params_from(referer)
                       .merge(submitted_dashboard_state_params)
                       .merge(extra_params.to_h.stringify_keys)
                       .compact_blank

      return missing_table_dashboard_path if uri.path == missing_table_dashboard_path

      dashboard_path(query_params)
    rescue URI::InvalidURIError
      dashboard_path(extra_params.to_h.stringify_keys.compact_blank)
    end

    def dashboard_query_params_from(referer)
      return {} if referer.blank?

      uri = URI.parse(referer)
      return {} unless [ root_path, dashboard_path, missing_table_dashboard_path ].include?(uri.path)

      Rack::Utils.parse_nested_query(uri.query)
                 .slice("duplicate_prefix", "duplicate_code", "duplicate_mode", "duplicates_page",
                        "missing_prefix", "missing_code", "missing_page")
    rescue URI::InvalidURIError
      {}
    end

    def submitted_dashboard_state_params
      params.to_unsafe_h.slice(
        "duplicate_prefix",
        "duplicate_code",
        "duplicate_mode",
        "duplicates_page",
        "missing_prefix",
        "missing_code",
        "missing_page"
      )
    end

    def success_message_for(result, status:)
      return if status == "missing" && result.unknown_codes.any?

      message = "Inventario actualizado."
      if result.unknown_codes.any? && status != "missing"
        message += " No se encontraron: #{result.unknown_codes.join(', ')}."
      end
      message
    end

    def unknown_codes_message_for(result, status:)
      return if status != "missing" || result.unknown_codes.empty?

      "No se encontraron estas fichas faltantes: #{result.unknown_codes.join(', ')}."
    end

    def consume_success_message_for(result, status:)
      return if result.processed_count.zero?

      status == "duplicate" ? "Tus repetidas se descontaron." : "Tus faltantes se actualizaron."
    end

    def consume_unknown_codes_message_for(result)
      return if result.unknown_codes.empty?

      "No se encontraron: #{result.unknown_codes.join(', ')}."
    end

    def consume_unavailable_codes_message_for(result, status:)
      return if result.unavailable_codes.empty?

      prefix = status == "duplicate" ? "Estas fichas no estaban en tus repetidas" : "Estas fichas no figuraban como faltantes"
      "#{prefix}: #{result.unavailable_codes.join(', ')}."
    end

    def consume_insufficient_codes_message_for(result)
      return if result.insufficient_codes.empty?

      "No tenías suficientes copias para descontar todas las apariciones de: #{result.insufficient_codes.join(', ')}."
    end
end
