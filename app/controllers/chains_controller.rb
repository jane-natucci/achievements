class ChainsController < ApplicationController
  before_action :set_chain, only: [:show, :edit, :update, :destroy]
  before_action :load_games, only: [:new, :create, :edit, :update]
  before_action :require_chain_creator!, only: [:edit, :update, :destroy]

  def index
    @filter_games = Game.joins(:chains).distinct.order(:name)
    @active_game = @filter_games.find_by(id: params[:game])
    @favorites_only = current_user.present? && params[:favorites] == "1"
    @chains = Chain.includes(:game, :creator, chain_nodes: :achievement).order(created_at: :desc)
    @chains = @chains.where(game: @active_game) if @active_game
    if @favorites_only
      @chains = Chain.joins(:user_chain_progresses).where(user_chain_progresses: { user_id: current_user.id, favorite: true })
    end
  end

  def show
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
    @chain = Chain.new
    @selected_achievements_payload = []
  end

  def edit
    @selected_achievements_payload = ordered_achievements_payload(@chain)
  end

  def create
    @chain = Chain.new(chain_params)
    @chain.creator = current_user
    selected_achievements = parse_selected_achievements
    selected_achievement_ids = selected_achievements.map { |item| item[:id] }

    achievements = validate_chain_selection(@chain, selected_achievement_ids)
    return render :new, status: :unprocessable_entity unless achievements

    ActiveRecord::Base.transaction do
      @chain.save!
      rebuild_chain_sequence!(@chain, selected_achievements)
    end

    redirect_to chain_path(@chain)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def update
    selected_achievements = parse_selected_achievements
    selected_achievement_ids = selected_achievements.map { |item| item[:id] }
    @chain.assign_attributes(chain_params)

    achievements = validate_chain_selection(@chain, selected_achievement_ids)
    return render :edit, status: :unprocessable_entity unless achievements

    ActiveRecord::Base.transaction do
      @chain.save!
      rebuild_chain_sequence!(@chain, selected_achievements)
    end

    redirect_to chain_path(@chain), notice: "Chain updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @chain.destroy!
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

  def set_chain
    @chain = Chain.includes(:game, :creator).find_by!(id: params[:id])
  end

  def chain_params
    params.require(:chain).permit(:title, :game_id, :description)
  end

  def load_games
    @games = Game.includes(:achievements).order(:name)
  end

  def parse_selected_achievements
    raw_payload = params.dig(:chain, :selected_achievement_ids)
    parsed_payload = JSON.parse(raw_payload.presence || "[]")

    Array(parsed_payload).filter_map do |value|
      if value.is_a?(Hash)
        achievement_id = Integer(value["id"] || value[:id], exception: false)
        next unless achievement_id

        {
          id: achievement_id,
          note: (value["note"] || value[:note]).to_s.strip.presence
        }
      else
        achievement_id = Integer(value, exception: false)
        next unless achievement_id

        {
          id: achievement_id,
          note: nil
        }
      end
    end.uniq { |item| item[:id] }
  rescue JSON::ParserError
    []
  end

  def validate_chain_selection(chain, selected_achievement_ids)
    if chain.title.blank?
      chain.errors.add(:title, "can't be blank")
      return nil
    end

    if selected_achievement_ids.empty?
      chain.errors.add(:base, "Select at least one achievement for the chain.")
      return nil
    end

    chain.game = @games.find_by(id: chain.game_id)

    unless chain.game
      chain.errors.add(:game, "must be selected.")
      return nil
    end

    achievements = chain.game.achievements.where(id: selected_achievement_ids).index_by(&:id)

    if achievements.size != selected_achievement_ids.size
      chain.errors.add(:base, "One or more selected achievements are invalid for the chosen game.")
      return nil
    end

    achievements
  end

  def rebuild_chain_sequence!(chain, selected_achievements)
    chain.chain_edges.delete_all
    chain.chain_nodes.destroy_all

    created_nodes = selected_achievements.map do |item|
      chain.chain_nodes.create!(ref_id: item[:id], note: item[:note])
    end

    created_nodes.each_cons(2) do |from_node, to_node|
      chain.chain_edges.create!(from_node: from_node.id, to_node: to_node.id, edge_type: "sequence")
    end
  end

  def ordered_achievements_payload(chain)
    ordered_nodes = chain.nodes_in_order
    nodes = ordered_nodes.presence || chain.chain_nodes
    nodes.map do |node|
      {
        id: node.ref_id,
        note: node.note
      }
    end
  end

  def require_chain_creator!
    return if @chain.creator && current_user && @chain.creator_user_id == current_user.id

    redirect_to chain_path(@chain), alert: "Only the chain creator can edit or delete this chain."
  end
end
