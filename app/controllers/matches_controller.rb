class MatchesController < ApplicationController
  before_action :require_current_group!

  def index
    @match_summaries = MatchmakingQuery.new(current_user, group: current_group).summaries
  end
end
