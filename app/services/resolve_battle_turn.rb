# Resolves one turn: an acting card (placed onto the board first if it's
# still in hand) attacks a target -- another card, or the opposing player
# directly ("attack player directly, bypassing the card in front" is
# always allowed; targeting is free, not lane-locked).
#
# Stance only ever modifies the acting card's own outgoing damage this
# turn -- it is never persisted on the card and never modifies incoming
# damage, since a card that isn't acting is always treated as neutral
# (confirmed behavior; means Defense stance currently has no defensive
# upside, a known balance quirk tracked in issue #57, not fixed here).
class ResolveBattleTurn
  STANCE_MULTIPLIERS = {
    "attack" => 1.25,
    "defense" => 0.75,
    "neutral" => 1.0
  }.freeze

  Result = Struct.new(:battle, :move, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end

  def self.call(battle:, side:, acting_card:, target:, stance: "neutral", slot: nil)
    new(battle, side, acting_card, target, stance, slot).call
  end

  def initialize(battle, side, acting_card, target, stance, slot)
    @battle = battle
    @side = side
    @acting_card = acting_card
    @target = target
    @stance = stance
    @slot = slot
  end

  def call
    error = validate
    return Result.new(battle: battle, error: error) if error

    move = nil

    ActiveRecord::Base.transaction do
      place_card! if acting_card.zone == "hand"

      damage = (acting_card.dmg * STANCE_MULTIPLIERS.fetch(stance)).round
      target_hp_after = apply_damage!(damage)

      move = battle.battle_moves.create!(
        turn_number: next_turn_number,
        acting_side: side,
        acting_battle_card: acting_card,
        target_type: target == :player ? "player" : "card",
        target_battle_card: target == :player ? nil : target,
        stance_used: stance,
        damage_dealt: damage,
        target_hp_after: target_hp_after
      )

      check_for_battle_end!
      advance_turn! if battle.active?
    end

    Result.new(battle: battle.reload, move: move)
  end

  private

  attr_reader :battle, :side, :acting_card, :target, :stance, :slot

  def validate
    return "Battle is already over." unless battle.active?
    return "It's not your turn." unless battle.current_turn_side == side
    return "That card can't act." unless acting_card.is_a?(BattleCard) && acting_card.battle_id == battle.id && acting_card.side == side
    return "That card can't act." unless acting_card.zone == "hand" || (acting_card.zone == "board" && acting_card.alive?)
    return "Unknown stance." unless STANCE_MULTIPLIERS.key?(stance)
    return "A slot is required to place a card." if acting_card.zone == "hand" && slot.blank?
    return "Invalid slot." if acting_card.zone == "hand" && !BattleCard::SLOTS.include?(slot)
    # A target card must actually be on the board -- a hand/deck card isn't
    # "in play" yet and shouldn't be attackable even if technically alive.
    return "Invalid target." unless target == :player || (target.is_a?(BattleCard) && target.battle_id == battle.id && target.side != side && target.zone == "board")

    nil
  end

  def place_card!
    acting_card.update!(zone: "board", slot: slot)
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

  def next_turn_number
    (battle.battle_moves.maximum(:turn_number) || 0) + 1
  end

  def check_for_battle_end!
    if battle.player_hp <= 0
      battle.update!(status: "lost")
    elsif battle.opponent_hp <= 0
      battle.update!(status: "won")
    end
  end

  def advance_turn!
    battle.update!(current_turn_side: battle.opposite_side(side))
    battle.skip_stuck_turns!
  end
end
