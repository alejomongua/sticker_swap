class InventoryItemsController < ApplicationController
  def create
    result = InventoryBulkUpsert.new(
      user: current_user,
      status: inventory_item_params[:status],
      codes: submitted_codes,
      quantity: inventory_item_params[:quantity]
    ).call

    if result.success?
      message = "Inventario actualizado."
      message += " No se encontraron: #{result.unknown_codes.join(', ')}." if result.unknown_codes.any?
      redirect_to dashboard_path, notice: message
    else
      redirect_to dashboard_path, alert: result.error_message
    end
  end

  def update
    inventory_item = current_user.inventory_items.find(params[:id])

    return redirect_to dashboard_path, alert: "Solo puedes ajustar la cantidad de tus repetidas." unless inventory_item.duplicate?

    quantity = Integer(update_params[:quantity], exception: false)
    return redirect_to dashboard_path, alert: "La cantidad debe ser un entero de 0 o más." if quantity.nil? || quantity.negative?

    if quantity.zero?
      inventory_item.destroy!
      redirect_to dashboard_path, notice: "La repetida se quitó de tu inventario."
    else
      inventory_item.update!(quantity: quantity)
      redirect_to dashboard_path, notice: "La cantidad de repetidas se actualizó."
    end
  rescue ActiveRecord::RecordInvalid => error
    redirect_to dashboard_path, alert: error.record.errors.full_messages.to_sentence
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
      return inventory_item_params[:code] if inventory_item_params[:status] == "duplicate"

      inventory_item_params[:codes]
    end

    def update_params
      params.require(:inventory_item).permit(:quantity)
    end
end
