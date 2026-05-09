class DashboardController < ApplicationController
  def show
    @duplicate_items = current_user.duplicate_items
    @duplicate_copies_count = @duplicate_items.sum(&:quantity)
    @missing_items = current_user.missing_items
  end
end
