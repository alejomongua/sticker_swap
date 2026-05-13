class DashboardController < ApplicationController
  include DashboardState

  before_action :prepare_dashboard_state, only: :show
  before_action :prepare_missing_table_state, only: :missing_table

  def show
    return render_dashboard_turbo_stream if request.format.turbo_stream? && turbo_frame_request_id == "dashboard_panel"

    render :show, formats: :html if request.format.turbo_stream?
  end

  def missing_table
    return render_missing_table_turbo_stream if request.format.turbo_stream? && turbo_frame_request_id == "missing_table"

    render :missing_table, formats: :html if request.format.turbo_stream?
  end
end
