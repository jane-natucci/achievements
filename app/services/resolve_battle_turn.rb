# Resolves one attack: an acting card (placed onto the board first if it's
# still in hand, into the first open slot -- no manual slot choice) attacks
# a target -- another card, or the opposing player directly (targeting is
# free, not lane-locked). Damage is flat (acting_card.dmg), no stance.
#
# Does NOT flip whose turn it is -- multiple cards can each act once per
# side's turn, so turn-ending is a separate, explicit step (see
# EndBattleTurn). This only marks the acting card as having acted.
class ResolveBattleTurn
  Result = Struct.new(:battle, :move, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end

  def self.call(battle:, side:, acting_card:, target:)
    new(battle, side, acting_card, target).call
  end

  def initialize(battle, side, acting_card, target)
    @battle = battle
    @side = side
    @acting_card = acting_card
    @target = target
  end

  def call
    error = validate
    return Result.new(battle: battle, error: error) if error

    move = nil

    ActiveRecord::Base.transaction do
      place_card! if acting_card.zone == "hand"

      damage = acting_card.dmg
      target_hp_after = apply_damage!(damage)

      move = battle.battle_moves.create!(
        move_number: next_move_number,
        acting_side: side,
        acting_battle_card: acting_card,
        target_type: target == :player ? "player" : "card",
        target_battle_card: target == :player ? nil : target,
        damage_dealt: damage,
        target_hp_after: target_hp_after
      )

      acting_card.update!(acted_this_turn: true)
      check_for_battle_end!
    end

    Result.new(battle: battle.reload, move: move)
  end

  private

  attr_reader :battle, :side, :acting_card, :target

  def validate
    return "Battle is already over." unless battle.active?
    return "It's not your turn." unless battle.current_turn_side == side
    return "That card can't act." unless acting_card.is_a?(BattleCard) && acting_card.battle_id == battle.id && acting_card.side == side
    return "That card can't act." unless acting_card.zone == "hand" || (acting_card.zone == "board" && acting_card.alive?)
    return "That card has already acted this turn." if acting_card.acted_this_turn?
    return "No open slot to place this card." if acting_card.zone == "hand" && open_slot.nil?
    # A target card must actually be on the board -- a hand/deck card isn't
    # "in play" yet and shouldn't be attackable even if technically alive.
    return "Invalid target." unless target == :player || (target.is_a?(BattleCard) && target.battle_id == battle.id && target.side != side && target.zone == "board")

    nil
  end

  def place_card!
    acting_card.update!(zone: "board", slot: open_slot)
  end

  def open_slot
    occupied = battle.cards_for(side).select { |card| card.zone == "board" }.map(&:slot)
    BattleCard::SLOTS.find { |slot| !occupied.include?(slot) }
  end

  def apply_damage!(damage)
    if target == :player
      opponent_side = battle.opposite_side(side)
      new_hp = [battle.hp_for(opponent_side) - damage, 0].max
      battle.update!(opponent_side == "player" ? { player_hp: new_hp } : { opponent_hp: new_hp })
      new_hp
    else
      new_hp = [target.hp_current - damage, 0].max
      target.update!(hp_current: new_hp, zone: (new_hp.zero? ? "dead" : target.zone))
      new_hp
    end
  end

  def next_move_number
    (battle.battle_moves.maximum(:move_number) || 0) + 1
  end

  def check_for_battle_end!
    if battle.player_hp <= 0
      battle.update!(status: "lost")
    elsif battle.opponent_hp <= 0
      battle.update!(status: "won")
    end
  end
end
