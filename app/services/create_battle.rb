# Starts a PvE battle: the given chain becomes the player's deck, and the
# opponent gets a mirrored copy of the same cards ("fight your shadow" --
# no separate opponent content exists yet, see issue #57). Up to
# CreateBattle::HAND_SIZE cards are dealt to each side's hand; the rest
# start in the deck, in the chain's own sequence order.
class CreateBattle
  HAND_SIZE = 3

  Result = Struct.new(:battle, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end

  def self.call(user:, chain:)
    new(user, chain).call
  end

  def initialize(user, chain)
    @user = user
    @chain = chain
  end

  def call
    return Result.new(error: "That chain has no achievements to battle with.") if achievements.empty?
    if achievements.size > Battle::MAX_DECK_SIZE
      return Result.new(error: "That chain has too many achievements to battle with (max #{Battle::MAX_DECK_SIZE}).")
    end

    battle = ActiveRecord::Base.transaction do
      battle = Battle.create!(user: user, deck_chain: chain, current_turn_side: first_mover)
      seed_cards!(battle, "player")
      seed_cards!(battle, "opponent")
      battle
    end

    battle.start_turn!(battle.current_turn_side)
    battle.skip_stuck_turns!
    ResolveAiTurn.call(battle: battle) if battle.active? && battle.current_turn_side == "opponent"

    Result.new(battle: battle)
  end

  private

  attr_reader :user, :chain

  def first_mover
    %w[player opponent].sample
  end

  def achievements
    @achievements ||= chain.nodes_in_order.filter_map(&:achievement)
  end

  def stats_by_achievement_id
    @stats_by_achievement_id ||= CardStats.for_achievements(achievements.map(&:id))
  end

  def seed_cards!(battle, side)
    achievements.each_with_index do |achievement, index|
      stats = stats_by_achievement_id.fetch(achievement.id)

      battle.battle_cards.create!(
        side: side,
        achievement: achievement,
        hp_max: stats.hp,
        hp_current: stats.hp,
        dmg: stats.dmg,
        zone: index < HAND_SIZE ? "hand" : "deck",
        deck_position: index
      )
    end
  end
end
