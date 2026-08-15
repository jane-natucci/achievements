# Starts a PvE battle: the given chain becomes the player's deck. The
# opponent -- still "your shadow" in spirit (see BattlesHelper) -- fields
# a different chain's cards, not a mirror of your own. While we're still
# testing this feature and most users have only created a single chain,
# that opponent chain is drawn from every battle-eligible chain in the
# system, not just this user's own, so there's actually some variety to
# fight against; falls back to mirroring the player's own chain if no
# other eligible chain exists yet. Up to CreateBattle::HAND_SIZE cards are
# dealt to each side's hand; the rest start in the deck, in the source
# chain's own sequence order. See issue #57.
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
    return Result.new(error: "That chain has no achievements to battle with.") if player_achievements.empty?
    if player_achievements.size > Battle::MAX_DECK_SIZE
      return Result.new(error: "That chain has too many achievements to battle with (max #{Battle::MAX_DECK_SIZE}).")
    end
    return Result.new(error: "You already have a battle in progress.") if user.battles.exists?(status: "active")

    battle = ActiveRecord::Base.transaction do
      battle = Battle.create!(user: user, deck_chain: chain, current_turn_side: first_mover)
      seed_cards!(battle, "player", player_achievements)
      seed_cards!(battle, "opponent", opponent_achievements)
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

  def player_achievements
    @player_achievements ||= chain.nodes_in_order.filter_map(&:achievement)
  end

  def opponent_achievements
    @opponent_achievements ||= (other_eligible_chains.sample || chain).nodes_in_order.filter_map(&:achievement)
  end

  def other_eligible_chains
    Chain.kept.where.not(id: chain.id).select { |candidate| candidate.chain_nodes.count.between?(1, Battle::MAX_DECK_SIZE) }
  end

  def seed_cards!(battle, side, achievements)
    stats_by_achievement_id = CardStats.for_achievements(achievements.map(&:id))

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
