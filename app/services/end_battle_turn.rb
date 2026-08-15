# What the "Ready" button calls: ends the given side's turn (regardless of
# whether they used every card -- using fewer is allowed) and starts the
# opponent's turn. If that leaves it the opponent's turn, resolves their
# entire turn via ResolveAiTurn (which also hands control back to the
# player once it's done), forwarding the block through so the caller can
# stream a step-by-step snapshot per opponent action.
class EndBattleTurn
  Result = Struct.new(:battle, :moves, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end

  def self.call(battle:, side:, &block)
    new(battle, side, &block).call
  end

  def initialize(battle, side, &block)
    @battle = battle
    @side = side
    @block = block
  end

  def call
    return Result.new(battle: battle, error: "Battle is already over.") unless battle.active?
    return Result.new(battle: battle, error: "It's not your turn.") unless battle.current_turn_side == side

    moves = []
    other = battle.opposite_side(side)

    ActiveRecord::Base.transaction do
      battle.update!(current_turn_side: other)
      battle.start_turn!(other)
      battle.skip_stuck_turns!

      if battle.active? && battle.current_turn_side == "opponent"
        ai_result = ResolveAiTurn.call(battle: battle, &block)
        @battle = ai_result.battle
        moves = ai_result.moves
      end
    end

    Result.new(battle: battle.reload, moves: moves)
  end

  private

  attr_reader :battle, :side, :block
end
