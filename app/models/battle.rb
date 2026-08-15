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

  def placed_card_this_turn?(side)
    side == "player" ? player_placed_card_this_turn : opponent_placed_card_this_turn
  end

  def mark_card_placed!(side)
    update!(side == "player" ? { player_placed_card_this_turn: true } : { opponent_placed_card_this_turn: true })
  end

  def open_slot?(side)
    cards_for(side).count { |card| card.zone == "board" } < BattleCard::SLOTS.size
  end

  # Whether this specific card could act this turn: an alive board card
  # that hasn't attacked yet this turn (this also covers a card placed
  # *this* turn -- placing marks it acted, so it can't attack until its
  # side's next turn resets that flag), or a hand card -- but only while
  # this side hasn't already placed a card this turn and has an open slot
  # (only one placement is allowed per side per turn).
  def actionable?(card)
    return false if card.acted_this_turn?
    return card.alive? if card.zone == "board"
    return false unless card.zone == "hand"

    !placed_card_this_turn?(card.side) && open_slot?(card.side)
  end

  # Cards this side could still act with this turn. Used both to gate
  # whether a side can act at all (see #skip_stuck_turns!) and to pick a
  # card for the AI to act with.
  def actionable_cards_for(side)
    cards_for(side).select { |card| actionable?(card) }
  end

  # The "beginning of a turn" event: resets this side's cards (and their
  # one-placement-per-turn budget) so they can act again, and -- from this
  # side's 2nd turn onward -- draws one card from their deck into their
  # hand (turn 1 keeps the opening hand as-is; confirmed behavior, not an
  # oversight).
  def start_turn!(side)
    if side == "player"
      increment!(:player_turn_count)
    else
      increment!(:opponent_turn_count)
    end

    update!(side == "player" ? { player_placed_card_this_turn: false } : { opponent_placed_card_this_turn: false })

    battle_cards.where(side: side, zone: %w[hand board]).update_all(acted_this_turn: false)
    # update_all bypasses ActiveRecord entirely -- it doesn't touch this
    # battle's own battle_cards association if something already loaded
    # and cached it earlier in the same request (e.g. rendering a board
    # snapshot mid-turn for the client). Without this reset, that stale
    # cache -- still showing the old acted_this_turn values -- is what
    # cards_for/actionable_cards_for would read next, wrongly judging a
    # side "stuck" right after resetting it.
    battle_cards.reset
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
