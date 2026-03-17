class ChainsController < ApplicationController
  def index
    @filter_games = Game.joins(:chains).distinct.order(:name)
    @active_game = @filter_games.find_by(id: params[:game])
    @favorites_only = current_user.present? && params[:favorites] == "1"
    @chains = Chain.includes(:game, :creator, chain_nodes: :achievement).order(created_at: :desc)
    @chains = @chains.where(game: @active_game) if @active_game
    if @favorites_only
      @chains = @chains.joins(:user_chain_progresses).where(user_chain_progresses: { user_id: current_user.id, favorite: true })
    end
    @favorite_chain_ids =
      if current_user
        current_user.user_chain_progresses.where(chain_id: @chains.map(&:id), favorite: true).pluck(:chain_id)
      else
        []
      end
  end

  def show
    @chain = Chain.includes(:game, :creator).find_by!(id: params[:id])
    @nodes = @chain.nodes_in_order
    @node_progress_by_node_id =
      if current_user
        UserNodeProgress.where(user: current_user, chain_node_id: @nodes.map(&:id), status: "completed").index_by(&:chain_node_id)
      else
        {}
      end
    @favorited = current_user.present? && current_user.user_chain_progresses.exists?(chain: @chain, favorite: true)
  end

  def new
    load_games
    @chain = Chain.new
  end

  def create
    load_games
    @chain = Chain.new(chain_params)
    @chain.creator = current_user
    selected_achievement_ids = parse_selected_achievement_ids

    if @chain.title.blank?
      @chain.errors.add(:title, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    if selected_achievement_ids.empty?
      @chain.errors.add(:base, "Select at least one achievement for the chain.")
      return render :new, status: :unprocessable_entity
    end

    @chain.game = @games.find_by(id: @chain.game_id)

    unless @chain.game
      @chain.errors.add(:game, "must be selected.")
      return render :new, status: :unprocessable_entity
    end

    achievements = @chain.game.achievements.where(id: selected_achievement_ids).index_by(&:id)

    if achievements.size != selected_achievement_ids.size
      @chain.errors.add(:base, "One or more selected achievements are invalid for the chosen game.")
      return render :new, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @chain.save!

      created_nodes = selected_achievement_ids.map do |achievement_id|
        @chain.chain_nodes.create!(ref_id: achievement_id)
      end

      created_nodes.each_cons(2) do |from_node, to_node|
        @chain.chain_edges.create!(from_node: from_node.id, to_node: to_node.id, edge_type: "sequence")
      end
    end

    redirect_to chain_path(@chain)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def destroy
    chain = Chain.find(params[:id])

    unless chain.creator && current_user && chain.creator_user_id == current_user.id
      return redirect_to chain_path(chain), alert: "Only the chain creator can delete this chain."
    end

    chain.destroy!
    redirect_to chains_path, notice: "Chain deleted."
  end

  def favorite
    return redirect_to("/achievements/login/", alert: "Log in to save chains.") unless current_user

    chain = Chain.find(params[:id])
    progress = UserChainProgress.find_or_initialize_by(user: current_user, chain: chain)
    progress.favorite = true
    progress.save!

    redirect_back fallback_location: chain_path(chain), notice: "Chain saved to your library."
  end

  def unfavorite
    return redirect_to("/achievements/login/", alert: "Log in to manage saved chains.") unless current_user

    chain = Chain.find(params[:id])
    progress = UserChainProgress.find_by(user: current_user, chain: chain)
    progress&.destroy if progress&.favorite?

    redirect_back fallback_location: chain_path(chain), notice: "Chain removed from your library."
  end

  private

  def chain_params
    params.require(:chain).permit(:title, :game_id, :description)
  end

  def load_games
    @games = Game.includes(:achievements).order(:name)
  end

  def parse_selected_achievement_ids
    raw_ids = params.dig(:chain, :selected_achievement_ids)
    parsed_ids = JSON.parse(raw_ids.presence || "[]")

    Array(parsed_ids).filter_map do |value|
      Integer(value, exception: false)
    end.uniq
  rescue JSON::ParserError
    []
  end
end
