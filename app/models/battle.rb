class Battle < ApplicationRecord
  STARTING_HP = 30
  MAX_DECK_SIZE = 15

  belongs_to :user
  belongs_to :deck_chain, class_name: "Chain"

  # battle_moves must be destroyed before battle_cards -- Rails runs
  # dependent: :destroy callbacks in declaration order, and moves hold a
  # not-null foreign key to the card that made them.
  has_many :battle_moves, dependent: :destroy
  has_many :battle_cards, dependent: :destroy

  def active?
    status == "active"
  end

  def player_cards
    battle_cards.select { |card| card.side == "player" }
  end

  def opponent_cards
    battle_cards.select { |card| card.side == "opponent" }
  end

  def cards_for(side)
    side == "player" ? player_cards : opponent_cards
  end

  def hp_for(side)
    side == "player" ? player_hp : opponent_hp
  end

  def opposite_side(side)
    side == "player" ? "opponent" : "player"
  end

  # Cards this side could still act with this turn -- either still in hand
  # (not yet placed) or alive on the board. Used both to gate whether a
  # side can act at all (see #skip_stuck_turns!) and to validate a
  # submitted turn.
  def actionable_cards_for(side)
    cards_for(side).select { |card| card.zone == "hand" || (card.zone == "board" && card.alive?) }
  end

  # Called after every turn transition (including battle creation, in case
  # the very first mover somehow starts with nothing). A side with no
  # actionable cards left just has its turn skipped so the other side keeps
  # going -- it does NOT end the battle by itself, since e.g. a player whose
  # cards all died should still keep taking direct hits from the opponent's
  # surviving cards. Only ends the battle immediately (by comparing HP) if
  # *neither* side has anything left to act with -- a true stalemate.
  def skip_stuck_turns!
    return unless active?
    return if actionable_cards_for(current_turn_side).any?

    other = opposite_side(current_turn_side)
    if actionable_cards_for(other).any?
      update!(current_turn_side: other)
    else
      winner_side = player_hp >= opponent_hp ? "player" : "opponent"
      update!(status: winner_side == "player" ? "won" : "lost")
    end
  end
end
