class StatisticsController < ApplicationController
  before_action :require_current_group!
  before_action :ensure_statistics_available!

  def show
    query = InventoryStatisticsQuery.new(group: current_group)

    @eligible_users_count = query.eligible_users_count
    @easiest_stickers = query.easiest
    @hardest_stickers = query.hardest
  end

  private
    def ensure_statistics_available!
      return if statistics_available?

      redirect_to dashboard_path,
                  alert: "Las estadísticas se habilitan cuando al menos 5 usuarios del grupo han cargado repetidas y faltantes."
    end
end
