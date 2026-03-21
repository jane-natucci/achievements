class AchievementsController < ApplicationController
  def index
    @chains = Chain.kept.includes(:game, chain_nodes: :achievement).order(created_at: :desc)
    @total_chains = @chains.size
    @total_achievements = @chains.sum { |chain| chain.chain_nodes.size }
    @filter_games = Game.joins(:chains).distinct.order(:name)
  end

  def help
  end
end
