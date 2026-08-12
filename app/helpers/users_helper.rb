module UsersHelper
  # "Wall of Text" from Victoria 3 -- borrowed for first_comment events since
  # a Comment has no icon of its own. Steam CDN URLs are content-hashed and
  # permanent, but the achievement's own row id is NOT stable across
  # environments (dev/prod each import their own Achievements table with
  # independently-assigned ids), so the achievement is looked up by its
  # title/game rather than a hardcoded id.
  FIRST_COMMENT_ICON_URL = "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/529340/ffd6c0c9e418f19f9300ee2039bf12ff76a8ec9a.jpg".freeze

  def xp_event_description(event)
    case event.reason
    when "profile_created"
      safe_join(["Created their profile! ", xp_amount_badge(event.amount)])
    when "achievement_unlocked"
      safe_join(["Unlocked ", chain_node_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "achievement_added"
      safe_join(["Added ", chain_node_link(event.subject), " to ", chain_node_chain_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "achievement_note"
      safe_join(["Wrote a note for ", chain_node_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "chain_created"
      safe_join(["Created ", chain_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "chain_description"
      safe_join(["Added a description to ", chain_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "chain_completed"
      safe_join(["Completed ", chain_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "first_comment"
      safe_join(["Left their first comment ", first_comment_location_link(event.subject), " ", xp_amount_badge(event.amount)])
    when "chain_favorited"
      safe_join(["Favorited ", chain_link(event.subject)])
    when "achievement_favorited"
      safe_join(["Favorited ", achievement_link(event.subject)])
    else
      safe_join(["#{event.reason.humanize} ", xp_amount_badge(event.amount)])
    end
  end

  # Distinguishes chain-related XP events from achievement-related ones at a
  # glance: achievements show their own icon, chains show their starting
  # achievement's icon with a small chain glyph badge, since a chain has no
  # icon of its own. Chain events additionally get a status glyph so
  # "created" and "completed" aren't visually identical. Whenever the icon
  # maps to a real achievement, only the icon itself (not the row's other
  # text) links to that achievement's page.
  def xp_event_subject_icon(event)
    return user_subject_icon(event.user) if event.reason == "profile_created"
    return first_comment_icon if event.reason == "first_comment"

    case event.subject_type
    when "ChainNode"
      achievement_subject_icon(event.subject&.achievement)
    when "Chain"
      chain_subject_icon(event.subject, event.reason)
    when "Achievement"
      achievement_subject_icon(event.subject)
    else
      content_tag(:span, "", class: "xp-feed__icon xp-feed__icon--placeholder", aria: { hidden: true })
    end
  end

  private

  def first_comment_icon
    icon = image_tag(FIRST_COMMENT_ICON_URL, alt: "")
    achievement_id = wall_of_text_achievement_id
    return content_tag(:span, icon, class: "xp-feed__icon") unless achievement_id

    link_to icon, achievement_path(achievement_id),
      class: "xp-feed__icon xp-feed__icon-link",
      title: "Wall of Text"
  end

  def wall_of_text_achievement_id
    Rails.cache.fetch("wall_of_text_achievement_id", expires_in: 1.day) do
      Achievement.joins(:game).find_by(title: "Wall of Text", games: { name: "Victoria 3" })&.id
    end
  end

  def user_subject_icon(user)
    if user&.avatar_url.present?
      image_tag(user.avatar_url, alt: "", class: "xp-feed__icon")
    else
      content_tag(:span, "", class: "xp-feed__icon xp-feed__icon--placeholder", aria: { hidden: true })
    end
  end

  def achievement_subject_icon(achievement)
    unless achievement&.icon_unlocked.present?
      return content_tag(:span, "", class: "xp-feed__icon xp-feed__icon--placeholder", aria: { hidden: true })
    end

    icon = image_tag(achievement.icon_unlocked, alt: "")
    link_to icon, achievement_path(achievement), class: "xp-feed__icon xp-feed__icon-link", title: achievement.title
  end

  def chain_subject_icon(chain, reason)
    cover_achievement = chain&.head&.achievement

    icon_content = capture do
      parts = []
      parts << image_tag(cover_achievement.icon_unlocked, alt: "", class: "xp-feed__icon-cover") if cover_achievement&.icon_unlocked.present?
      parts << content_tag(:span, "⛓️", class: "xp-feed__icon-glyph")
      parts << content_tag(:span, "✨", class: "xp-feed__icon-status-glyph") unless reason.in?(%w[chain_completed chain_favorited])
      safe_join(parts)
    end

    if cover_achievement
      link_to icon_content, achievement_path(cover_achievement),
        class: "xp-feed__icon xp-feed__icon--chain xp-feed__icon-link",
        title: cover_achievement.title
    else
      content_tag(:span, icon_content, class: "xp-feed__icon xp-feed__icon--chain", aria: { hidden: true })
    end
  end

  # Links to the exact spot a first_comment event's Comment was posted
  # (deep-linked via its #comment-ID anchor, see comments/_comments.html.erb).
  # Falls back to plain text if the comment or its commentable was since
  # deleted -- the XpEvent itself is never removed.
  def first_comment_location_link(comment)
    return "somewhere" unless comment&.commentable

    link_to "here", polymorphic_path(comment.commentable, anchor: "comment-#{comment.id}"), class: "xp-feed__entity-link"
  end

  def chain_node_link(chain_node)
    return "an achievement" unless chain_node

    achievement = chain_node.achievement
    return chain_node.title unless achievement

    link_to achievement.title, achievement_path(achievement), class: "xp-feed__entity-link"
  end

  def chain_link(chain)
    return "a chain" unless chain

    link_to chain.title, chain_path(chain), class: "xp-feed__entity-link"
  end

  def achievement_link(achievement)
    return "an achievement" unless achievement

    link_to achievement.title, achievement_path(achievement), class: "xp-feed__entity-link"
  end

  # Links the word "chain" itself (rather than the chain's title) to the
  # specific chain a ChainNode belongs to, for the "Added X to a chain"
  # sentence -- the chain_node's own association already tells us which one.
  def chain_node_chain_link(chain_node)
    chain = chain_node&.chain
    return "a chain" unless chain

    link_to "a chain", chain_path(chain), class: "xp-feed__entity-link"
  end

  def xp_amount_badge(amount)
    content_tag(:span, "+#{amount} XP", class: "xp-badge")
  end
end
