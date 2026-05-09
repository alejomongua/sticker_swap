class MatchesController < ApplicationController
  def index
    @match_summaries = MatchmakingQuery.new(current_user).summaries
  end
end
