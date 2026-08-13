# Resolves the opponent's turn in a PvE battle: a random actionable card
# attacks a random valid target (another alive player card, or the player
# directly) in a random stance. No difficulty tuning yet -- this exists so
# a battle is actually playable before any real opponent-AI design pass.
#
# By the time this is called, Battle#skip_stuck_turns! (run after every
# turn transition) has already guaranteed current_turn_side is "opponent"
# only if the opponent actually has an actionable card -- so no stuck-turn
# handling needed here.
class BattleAiTurn
  STANCES = %w[attack defense neutral].freeze

  def self.call(battle:)
    new(battle).call
  end

  def initialize(battle)
    @battle = battle
  end

  def call
    card = battle.actionable_cards_for("opponent").sample
    return ResolveBattleTurn::Result.new(battle: battle, error: "Opponent has no actionable cards.") unless card

    target = pick_target
    slot = card.zone == "hand" ? BattleCard::SLOTS.sample : nil

    ResolveBattleTurn.call(battle: battle, side: "opponent", acting_card: card, target: target, stance: STANCES.sample, slot: slot)
  end

  private

  attr_reader :battle

  def pick_target
    # Only cards actually on the board are valid targets -- a hand/deck
    # card isn't "in play" yet, even though it's technically alive.
    board_player_cards = battle.cards_for("player").select { |card| card.zone == "board" }
    return :player if board_player_cards.empty?

    ([:player] + board_player_cards).sample
  end
end
