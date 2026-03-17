class AchievementsController < ApplicationController
  def index
    @chains = Chain.includes(:game, chain_nodes: :achievement).order(created_at: :desc)
    @total_chains = @chains.size
    @total_achievements = @chains.sum { |chain| chain.chain_nodes.size }
    @filter_games = Game.joins(:chains).distinct.order(:name)
    @favorite_chain_ids =
      if current_user
        current_user.user_chain_progresses.where(chain_id: @chains.map(&:id), favorite: true).pluck(:chain_id)
      else
        []
      end
  end

  def help
  end
end
