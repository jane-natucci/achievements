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

  # Distinguishes chain-related XP events from achievement-related ones at a
  # glance: achievements show their own icon, chains show their starting
  # achievement's icon with a small chain glyph badge, since a chain has no
  # icon of its own. Chain events additionally get a status glyph so
  # "created" and "completed" aren't visually identical.
  def xp_event_subject_icon(event)
    case event.subject_type
    when "ChainNode"
      achievement_subject_icon(event.subject&.achievement)
    when "Chain"
      chain_subject_icon(event.subject, event.reason)
    else
      content_tag(:span, "", class: "xp-feed__icon xp-feed__icon--placeholder", aria: { hidden: true })
    end
  end

  private

  def achievement_subject_icon(achievement)
    if achievement&.icon_unlocked.present?
      image_tag(achievement.icon_unlocked, alt: "", class: "xp-feed__icon")
    else
      content_tag(:span, "", class: "xp-feed__icon xp-feed__icon--placeholder", aria: { hidden: true })
    end
  end

  def chain_subject_icon(chain, reason)
    cover_achievement = chain&.head&.achievement
    status_glyph = reason == "chain_completed" ? "✅" : "✨"

    content_tag(:span, class: "xp-feed__icon xp-feed__icon--chain", aria: { hidden: true }) do
      parts = []
      parts << image_tag(cover_achievement.icon_unlocked, alt: "", class: "xp-feed__icon-cover") if cover_achievement&.icon_unlocked.present?
      parts << content_tag(:span, "⛓️", class: "xp-feed__icon-glyph")
      parts << content_tag(:span, status_glyph, class: "xp-feed__icon-status-glyph")
      safe_join(parts)
    end
  end

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
