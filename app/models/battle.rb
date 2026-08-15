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

  def turn_count_for(side)
    side == "player" ? player_turn_count : opponent_turn_count
  end

  # Cards this side could still act with this turn: alive board cards that
  # haven't already attacked this turn, or hand cards -- but only while
  # there's an open board slot to place them into (otherwise BattleAiTurn
  # could pick an unplaceable hand card, ResolveBattleTurn would reject it,
  # and a turn-resolution loop would stop early even though other cards on
  # this side could still act). Used both to gate whether a side can act at
  # all (see #skip_stuck_turns!) and to validate an attack.
  def actionable_cards_for(side)
    open_slots = BattleCard::SLOTS.size - cards_for(side).count { |card| card.zone == "board" }

    cards_for(side).select do |card|
      next false if card.acted_this_turn?
      next true if card.zone == "board" && card.alive?

      card.zone == "hand" && open_slots.positive?
    end
  end

  # The "beginning of a turn" event: resets this side's cards so they can
  # act again, and -- from this side's 2nd turn onward -- draws one card
  # from their deck into their hand (turn 1 keeps the opening hand as-is;
  # confirmed behavior, not an oversight).
  def start_turn!(side)
    if side == "player"
      increment!(:player_turn_count)
    else
      increment!(:opponent_turn_count)
    end

    battle_cards.where(side: side, zone: %w[hand board]).update_all(acted_this_turn: false)
    draw_card!(side) if turn_count_for(side) >= 2
  end

  def draw_card!(side)
    next_card = cards_for(side).select { |card| card.zone == "deck" }.min_by(&:deck_position)
    next_card&.update!(zone: "hand")
  end

  # Called after every turn transition (including battle creation, in case
  # the very first mover somehow starts with nothing). A side with no
  # actionable cards left just has its turn skipped so the other side keeps
  # going -- it does NOT end the battle by itself, since e.g. a player whose
  # cards all died should still keep taking direct hits from the opponent's
  # surviving cards. Only ends the battle immediately (by comparing HP) if
  # *neither* side has anything left to act with -- a true stalemate.
  #
  # start_turn! runs *before* the stuck-check on the incoming side, not
  # after: a side with an empty hand/board but cards still in their deck
  # should get a fresh draw before being judged "stuck", or they'd be
  # skipped forever despite having a deck.
  def skip_stuck_turns!
    return unless active?
    return if actionable_cards_for(current_turn_side).any?

    other = opposite_side(current_turn_side)
    update!(current_turn_side: other)
    start_turn!(other)

    return if actionable_cards_for(other).any?

    winner_side = player_hp >= opponent_hp ? "player" : "opponent"
    update!(status: winner_side == "player" ? "won" : "lost")
  end
end
