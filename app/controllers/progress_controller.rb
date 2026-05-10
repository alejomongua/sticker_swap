class ProgressController < ApplicationController
  def show
    query = InventoryProgressQuery.new(current_user)

    @progress_summary = query.summary
    @progress_entries = query.entries
    @selected_progress_code = params[:group].to_s.strip.upcase.presence
    @selected_progress_detail = query.detail_for(@selected_progress_code)
  end
end
