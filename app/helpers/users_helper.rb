module UsersHelper
  def xp_event_description(event)
    case event.reason
    when "profile_created"
      "Created their profile! (+#{event.amount} xp)"
    when "achievement_unlocked"
      safe_join(["Unlocked ", chain_node_link(event.subject), " (+#{event.amount} xp)"])
    when "achievement_added"
      safe_join(["Added ", chain_node_link(event.subject), " to a chain (+#{event.amount} xp)"])
    when "achievement_note"
      safe_join(["Wrote a note for ", chain_node_link(event.subject), " (+#{event.amount} xp)"])
    when "chain_created"
      safe_join(["Created ", chain_link(event.subject), " (+#{event.amount} xp)"])
    when "chain_description"
      safe_join(["Added a description to ", chain_link(event.subject), " (+#{event.amount} xp)"])
    when "chain_completed"
      safe_join(["Completed ", chain_link(event.subject), " (+#{event.amount} xp)"])
    else
      "#{event.reason.humanize} (+#{event.amount} xp)"
    end
  end

  private

  def chain_node_link(chain_node)
    return "an achievement" unless chain_node

    achievement = chain_node.achievement
    return chain_node.title unless achievement

    link_to achievement.title, achievement_path(achievement)
  end

  def chain_link(chain)
    return "a chain" unless chain

    link_to chain.title, chain_path(chain)
  end
end
