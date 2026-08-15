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
end
