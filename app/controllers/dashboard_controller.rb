class DashboardController < ApplicationController
  include DashboardState

  before_action :prepare_dashboard_state, only: :show
  before_action :prepare_import_export_state, only: %i[ import_export compare_external ]
  before_action :prepare_missing_table_state, only: :missing_table

  def show
    return render_dashboard_turbo_stream if request.format.turbo_stream? && turbo_frame_request_id == "dashboard_panel"

    render :show, formats: :html if request.format.turbo_stream?
  end

  def missing_table
    return render_missing_table_turbo_stream if request.format.turbo_stream? && turbo_frame_request_id == "missing_table"

    render :missing_table, formats: :html if request.format.turbo_stream?
  end

  def import_export
  end

  def compare_external
    @external_inventory_text = external_inventory_match_params[:text]
    @external_inventory_match = ExternalInventoryMatchPreview.new(
      user: current_user,
      text: @external_inventory_text
    ).call

    render :import_export, status: @external_inventory_match.success? ? :ok : :unprocessable_content
  end

  private
    def external_inventory_match_params
      params.require(:external_inventory_match).permit(:text)
    end
end
