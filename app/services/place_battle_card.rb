# Places a hand card onto the board (first open slot). This is its whole
# action for the turn -- it does not attack the same turn it's placed
# (marking it acted_this_turn blocks that until its side's next turn
# resets the flag) -- and a side may only place one card per turn.
#
# Reuses ResolveBattleTurn::Result so callers that don't care whether an
# action was a placement or an attack (ResolveAiTurn's loop) can treat
# both uniformly. A placement has no move (nothing attacked, no damage),
# so result.move is always nil here.
class PlaceBattleCard
  def self.call(battle:, side:, card:)
    new(battle, side, card).call
  end

  def initialize(battle, side, card)
    @battle = battle
    @side = side
    @card = card
  end

  def call
    error = validate
    return ResolveBattleTurn::Result.new(battle: battle, error: error) if error

    ActiveRecord::Base.transaction do
      card.update!(zone: "board", slot: open_slot, acted_this_turn: true)
      battle.mark_card_placed!(side)
    end

    ResolveBattleTurn::Result.new(battle: battle.reload)
  end

  private

  attr_reader :battle, :side, :card

  def validate
    return "Battle is already over." unless battle.active?
    return "It's not your turn." unless battle.current_turn_side == side
    return "That card can't be placed." unless card.is_a?(BattleCard) && card.battle_id == battle.id && card.side == side && card.zone == "hand"
    return "Already placed a card this turn." if battle.placed_card_this_turn?(side)
    return "No open slot to place this card." if open_slot.nil?

    nil
  end

  def open_slot
    occupied = battle.cards_for(side).select { |c| c.zone == "board" }.map(&:slot)
    BattleCard::SLOTS.find { |slot| !occupied.include?(slot) }
  end
end
