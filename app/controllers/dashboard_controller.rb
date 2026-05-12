class DashboardController < ApplicationController
  include DashboardState

  before_action :prepare_dashboard_state, only: :show
  before_action :prepare_missing_table_state, only: :missing_table

  def show
    respond_to do |format|
      format.html
      format.turbo_stream { render_dashboard_turbo_stream }
    end
  end

  def missing_table
    respond_to do |format|
      format.html
      format.turbo_stream { render_missing_table_turbo_stream }
    end
  end
end
