class ProgressController < ApplicationController
  def show
    query = InventoryProgressQuery.new(current_user)

    @progress_summary = query.summary
    @progress_entries = query.entries
  end
end