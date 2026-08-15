# Resolves one action for the opponent in a PvE battle: a random
# actionable card either gets placed (if it's in hand) or attacks a
# random valid target (if it's on the board) -- another alive player
# card, or the player directly. No difficulty tuning yet -- this exists
# so a battle is actually playable before any real opponent-AI design
# pass.
#
# Deliberately scoped to exactly one action (not the opponent's whole
# turn) so it stays the reusable "one AI move" primitive -- ResolveAiTurn
# loops this to run a full opponent turn.
class BattleAiTurn
  def self.call(battle:)
    new(battle).call
  end

  def initialize(battle)
    @battle = battle
  end

  def call
    card = battle.actionable_cards_for("opponent").sample
    return ResolveBattleTurn::Result.new(battle: battle, error: "Opponent has no actionable cards.") unless card

    if card.zone == "hand"
      PlaceBattleCard.call(battle: battle, side: "opponent", card: card, slot: open_slots.sample)
    else
      ResolveBattleTurn.call(battle: battle, side: "opponent", acting_card: card, target: pick_target)
    end
  end

  private

  attr_reader :battle

  def open_slots
    occupied = battle.cards_for("opponent").select { |card| card.zone == "board" }.map(&:slot)
    BattleCard::SLOTS - occupied
  end

  def pick_target
    # Only cards actually on the board are valid targets -- a hand/deck
    # card isn't "in play" yet, even though it's technically alive.
    board_player_cards = battle.cards_for("player").select { |card| card.zone == "board" }
    return :player if board_player_cards.empty?

    ([:player] + board_player_cards).sample
  end
end
