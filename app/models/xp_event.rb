class XpEvent < ApplicationRecord
  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  # An achievement that belongs to several chains gets an XpEvent per
  # chain_node it fills when unlocked (see SyncUserAchievementProgress) --
  # correct for XP, but any feed would otherwise show one "unlocked" row
  # per chain for what's really one person unlocking one achievement, so
  # those collapse to the earliest one per user+achievement. Used on both
  # the sitewide feed and a user's own profile feed -- unlike the
  # incidental-chain-completion suppression below, this isn't specific to
  # the sitewide feed, since the same duplication happens either place.
  #
  # `scope` lets a caller pre-filter (e.g. to one user's own events) before
  # this collapsing runs; defaults to every event.
  def self.collapse_achievement_unlock_duplicates(scope = all)
    # Only an achievement_unlocked event with a ChainNode subject is the
    # per-chain duplication case -- anything else (including any stray
    # achievement_unlocked event without one) passes through untouched.
    chain_node_unlocks = scope.where(reason: "achievement_unlocked", subject_type: "ChainNode")
    other_ids = scope.where.not(id: chain_node_unlocks.select(:id)).pluck(:id)

    unlock_rows = chain_node_unlocks.pluck(:id, :user_id, :subject_id, :created_at)
    achievement_id_by_chain_node_id = ChainNode.where(id: unlock_rows.map { |row| row[2] }).pluck(:id, :ref_id).to_h

    earliest_unlock_ids = unlock_rows.group_by do |(_id, user_id, chain_node_id, _created_at)|
      achievement_id = achievement_id_by_chain_node_id[chain_node_id]
      # No achievement to resolve to (e.g. an orphaned chain_node) -- don't
      # risk merging unrelated unlocks together, just leave it ungrouped.
      achievement_id ? [ user_id, achievement_id ] : [ user_id, :chain_node, chain_node_id ]
    end.values.map { |rows| rows.min_by { |row| row[3] }[0] }

    other_ids + earliest_unlock_ids
  end

  # SyncUserAchievementProgress#award_chain_completion_bonuses! awards a
  # chain_completed event to EVERY user whose already-unlocked achievements
  # happen to satisfy a chain's nodes, not just someone who deliberately
  # followed it. Most chains are a player's own auto-generated "next steps"
  # suggestion (see SessionsController#create_chain_from_params), so a
  # single new player syncing their (often extensive) existing Steam
  # history can incidentally "complete" dozens of other players' tiny
  # suggestion chains in one go, drowning out everything else in the
  # sitewide feed. Keep the sitewide feed to a chain's own creator
  # completing it; other completions still count for XP and still show on
  # the completer's own profile (see UsersHelper#xp_event_description),
  # just not here -- so this is deliberately NOT folded into the profile
  # feed's own filtering.
  def self.incidental_chain_completion_ids(candidates)
    candidates.where(reason: "chain_completed", subject_type: "Chain")
              .joins("INNER JOIN chains ON chains.id = xp_events.subject_id")
              .where.not("chains.creator_user_id = xp_events.user_id")
              .select(:id)
  end

  # Sitewide feed visibility: drops "added to chain" noise, hides
  # incidental (non-creator) chain completions, then collapses
  # per-chain-node achievement_unlocked duplicates.
  def self.visible_ids(scope = all)
    candidates = scope.where.not(reason: "achievement_added")
    non_incidental = candidates.where.not(id: incidental_chain_completion_ids(candidates))
    collapse_achievement_unlock_duplicates(non_incidental)
  end
end
