module BattlesHelper
  def battle_player_name(battle)
    battle.user.display_name.presence || "You"
  end

  def battle_player_link(battle)
    link_to battle_player_name(battle), user_path(battle.user), target: "_blank", rel: "noopener noreferrer", class: "battle-log__player-link"
  end

  def battle_shadow_name(battle)
    "#{battle_player_name(battle)}'s Shadow"
  end

  def battle_player_deck_link(battle)
    battle_deck_link(battle.deck_chain)
  end

  # The opponent's deck chain is nullable -- battles created before that
  # column existed mirrored the player's own chain, so that's the
  # correct fallback for them too.
  def battle_opponent_deck_link(battle)
    battle_deck_link(battle.opponent_deck_chain || battle.deck_chain)
  end

  private

  def battle_deck_link(chain)
    link_to chain.title, chain_path(chain), target: "_blank", rel: "noopener noreferrer", class: "battle-log__player-link"
  end
end
