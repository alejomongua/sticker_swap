class InventoryItemsController < ApplicationController
  def create
    result = InventoryBulkUpsert.new(
      user: current_user,
      status: inventory_item_params[:status],
      codes: submitted_codes,
      quantity: inventory_item_params[:quantity]
    ).call

    if result.success?
      flash[:notice] = success_message_for(result)
      flash[:alert] = incoherence_alert_for(result.conflicts) if result.conflicts.any?

      redirect_to dashboard_return_location(duplicate_mode: params[:duplicate_mode]), status: :see_other
    else
      redirect_to dashboard_return_location(duplicate_mode: params[:duplicate_mode]), alert: result.error_message, status: :see_other
    end
  end

  def update
    inventory_item = current_user.inventory_items.find(params[:id])

    return redirect_to(dashboard_return_location, alert: "Solo puedes ajustar la cantidad de tus repetidas.", status: :see_other) unless inventory_item.duplicate?

    quantity = Integer(update_params[:quantity], exception: false)
    return redirect_to(dashboard_return_location, alert: "La cantidad debe ser un entero de 0 o más.", status: :see_other) if quantity.nil? || quantity.negative?

    if quantity.zero?
      inventory_item.destroy!
      redirect_to dashboard_return_location, notice: "La repetida se quitó de tu inventario.", status: :see_other
    else
      inventory_item.update!(quantity: quantity)
      redirect_to dashboard_return_location, notice: "La cantidad de repetidas se actualizó.", status: :see_other
    end
  rescue ActiveRecord::RecordInvalid => error
    redirect_to dashboard_return_location, alert: error.record.errors.full_messages.to_sentence, status: :see_other
  end

  def destroy
    inventory_item = current_user.inventory_items.find(params[:id])
    notice = inventory_item.missing? ? "La figura ya no figura como faltante." : "La figura se quitó de tus repetidas."

    inventory_item.destroy!
    redirect_back fallback_location: dashboard_path, notice: notice, status: :see_other
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

    def dashboard_return_location(extra_params = {})
      referer = request.referer.to_s
      query_params = dashboard_query_params_from(referer).merge(extra_params.to_h.stringify_keys).compact_blank

      dashboard_path(query_params)
    end

    def dashboard_query_params_from(referer)
      return {} if referer.blank?

      uri = URI.parse(referer)
      return {} unless [ root_path, dashboard_path ].include?(uri.path)

      Rack::Utils.parse_nested_query(uri.query)
                 .slice("duplicate_prefix", "duplicate_code", "duplicate_mode", "duplicates_page",
                        "missing_prefix", "missing_code", "missing_page")
    rescue URI::InvalidURIError
      {}
    end

    def success_message_for(result)
      message = "Inventario actualizado."
      message += " No se encontraron: #{result.unknown_codes.join(', ')}." if result.unknown_codes.any?
      message
    end

    def incoherence_alert_for(conflicts)
      changes = conflicts.map do |conflict|
        "#{conflict.code}: de #{human_inventory_status(conflict.previous_status)} a #{human_inventory_status(conflict.new_status)}"
      end

      "Posible incoherencia en tu inventario. Revisa #{changes.join(', ')}."
    end

    def human_inventory_status(status)
      status == "duplicate" ? "repetida" : "faltante"
    end
end
