# Runs the opponent's entire turn: every actionable opponent card attacks
# once, in sequence (mirroring the player's "each card gets a turn" rule),
# until none are left or the battle ends. Yields (battle, move) after each
# resolved action via the given block, if any -- this is what lets the
# caller stream a step-by-step snapshot back to the client for a delayed
# reveal, without this service knowing anything about HTML/JSON.
#
# BattleAiTurn's existing "no actionable cards" error is the natural stop
# signal for the loop, not a failure -- it just means the opponent's turn
# is over.
#
# Expects the opponent's turn to have already been started (see
# Battle#start_turn!) by the caller before this runs. Hands control back to
# the player (flips current_turn_side and starts their turn) once the loop
# ends, provided the battle is still active.
class ResolveAiTurn
  Result = Struct.new(:battle, :moves, keyword_init: true)

  def self.call(battle:, &block)
    new(battle, &block).call
  end

  def initialize(battle, &block)
    @battle = battle
    @block = block
  end

  def call
    moves = []

    while battle.active? && battle.current_turn_side == "opponent"
      result = BattleAiTurn.call(battle: battle)
      break if result.error

      @battle = result.battle
      moves << result.move
      block&.call(battle, result.move)
    end

    if battle.active?
      battle.update!(current_turn_side: "player")
      battle.start_turn!("player")
      battle.skip_stuck_turns!
    end

    Result.new(battle: battle.reload, moves: moves)
  end

  private

  attr_reader :battle, :block
end
