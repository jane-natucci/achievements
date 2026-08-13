class BattlesController < ApplicationController
  before_action :set_battle, only: [:show, :turn]
  before_action :require_own_battle!, only: [:show, :turn]

  def index
    return redirect_to("/achievements/login/", alert: "Log in to see your battles.") unless current_user

    @battles = current_user.battles.order(created_at: :desc)
  end

  def new
    return redirect_to("/achievements/login/", alert: "Log in to start a battle.") unless current_user

    @eligible_chains = current_user.created_chains.kept.select { |chain| chain.chain_nodes.count.between?(1, Battle::MAX_DECK_SIZE) }
  end

  def create
    return redirect_to("/achievements/login/", alert: "Log in to start a battle.") unless current_user

    chain = Chain.kept.find(params[:chain_id])
    result = CreateBattle.call(user: current_user, chain: chain)

    if result.success?
      redirect_to battle_path(result.battle)
    else
      redirect_to new_battle_path, alert: result.error
    end
  end

  def show
  end

  # JSON: resolves the player's turn, then (unless the battle just ended)
  # the opponent's reply -- two board snapshots so the client can show
  # them a couple seconds apart without a page reload.
  def turn
    unless @battle.active?
      return render json: { error: "Battle is already over." }, status: :unprocessable_entity
    end

    acting_card = @battle.battle_cards.find_by(id: params[:acting_card_id])
    target = resolve_target
    result = ResolveBattleTurn.call(
      battle: @battle,
      side: "player",
      acting_card: acting_card,
      target: target,
      stance: params[:stance].to_s,
      slot: params[:slot]
    )

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    mid_html = render_to_string(partial: "board", formats: [:html], locals: { battle: @battle })
    mid_move_html = render_to_string(partial: "move_log_entry", formats: [:html], locals: { move: result.move })

    ai_result = nil
    if @battle.current_turn_side == "opponent"
      ai_result = BattleAiTurn.call(battle: @battle)
    end

    final_html = ai_result ? render_to_string(partial: "board", formats: [:html], locals: { battle: @battle }) : nil
    final_move_html = ai_result&.move ? render_to_string(partial: "move_log_entry", formats: [:html], locals: { move: ai_result.move }) : nil

    render json: {
      mid_html: mid_html,
      mid_move_html: mid_move_html,
      final_html: final_html,
      final_move_html: final_move_html,
      battle_over: @battle.active? ? false : @battle.status
    }
  end

  private

  def set_battle
    @battle = Battle.find(params[:id])
  end

  def require_own_battle!
    return if current_user && @battle.user_id == current_user.id

    redirect_to battles_path, alert: "That's not your battle."
  end

  def resolve_target
    return :player if params[:target_type] == "player"

    @battle.battle_cards.find_by(id: params[:target_battle_card_id])
  end
end
