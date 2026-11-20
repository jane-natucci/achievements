# A game's achievements as JSON, for the chain builder: it asks for them when a game is picked, instead of the form
# carrying every game's achievements in the page.
class Games::AchievementsController < ApplicationController
  def index
    game = Game.find(params[:game_id])

    render json: game.achievements.order(:title).map { |achievement|
      achievement.slice(:id, :title, :description, :icon_unlocked)
    }
  end
end
