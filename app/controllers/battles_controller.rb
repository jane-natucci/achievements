class BattlesController < ApplicationController
  before_action :set_battle, only: [:show, :attack, :end_turn]
  before_action :require_own_battle!, only: [:show, :attack, :end_turn]

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

  # JSON: resolves a single instant attack for the player. Does not end
  # their turn -- other cards can still act after this.
  def attack
    unless @battle.active?
      return render json: { error: "Battle is already over." }, status: :unprocessable_entity
    end

    acting_card = @battle.battle_cards.find_by(id: params[:acting_card_id])
    target = resolve_target
    result = ResolveBattleTurn.call(battle: @battle, side: "player", acting_card: acting_card, target: target)

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    render json: {
      board_html: render_to_string(partial: "board", formats: [:html], locals: { battle: result.battle }),
      move_html: render_to_string(partial: "move_log_entry", formats: [:html], locals: { move: result.move }),
      battle_over: result.battle.active? ? false : result.battle.status
    }
  end

  # JSON: ends the player's turn and resolves the opponent's entire reply
  # turn (however many cards they act with) server-side, returning one
  # {board_html, move_html} snapshot per opponent action so the client can
  # reveal them a couple seconds apart without a page reload, plus a final
  # snapshot reflecting the hand-back to the player (their own draw, etc).
  def end_turn
    unless @battle.active?
      return render json: { error: "Battle is already over." }, status: :unprocessable_entity
    end

    steps = []
    result = EndBattleTurn.call(battle: @battle, side: "player") do |battle_snapshot, move|
      steps << {
        board_html: render_to_string(partial: "board", formats: [:html], locals: { battle: battle_snapshot }),
        move_html: render_to_string(partial: "move_log_entry", formats: [:html], locals: { move: move })
      }
    end

    return render json: { error: result.error }, status: :unprocessable_entity unless result.success?

    render json: {
      steps: steps,
      final_html: render_to_string(partial: "board", formats: [:html], locals: { battle: result.battle }),
      battle_over: result.battle.active? ? false : result.battle.status
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
