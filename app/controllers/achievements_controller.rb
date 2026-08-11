class AchievementsController < ApplicationController
  def index
    @recent_events = XpEvent.includes(:user).order(created_at: :desc).limit(30)

    chains = Chain.kept
    @total_chains = chains.size
    @total_achievements = ChainNode.joins(:chain).where(chain_id: chains.select(:id)).count
    @filter_games = Game.joins(:chains).distinct.order(:name)
  end

  def show
    @achievement = Achievement.includes(:game).find(params[:id])
    @chain_nodes = @achievement.chain_nodes.includes(chain: :game).joins(:chain).merge(Chain.kept).order(created_at: :asc)
  end

  def help
  end
end
