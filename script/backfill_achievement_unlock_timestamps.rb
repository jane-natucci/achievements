# frozen_string_literal: true

# One-off backfill: corrects created_at on already-recorded achievement_unlocked
# XpEvents (and their underlying UserNodeProgress rows) to match the real Steam
# unlock time, for rows synced before app/services/sync_user_achievement_progress.rb
# started passing occurred_at. Without this, an achievement someone unlocked long
# ago -- but only just added to a chain -- reads as having happened "now" in the
# activity feed.
#
# Dry-run by default; pass "commit" as the runner arg to actually write:
#   bin/rails runner script/backfill_achievement_unlock_timestamps.rb          # dry run
#   bin/rails runner script/backfill_achievement_unlock_timestamps.rb commit   # applies changes

commit = ARGV.first == "commit"

progresses = UserNodeProgress.where(status: "completed", source: "steam")
                              .where.not(unlocked_at: nil)

fixed = 0

progresses.find_each do |progress|
  event = XpEvent.find_by(
    user_id: progress.user_id,
    reason: "achievement_unlocked",
    subject_type: "ChainNode",
    subject_id: progress.chain_node_id
  )

  next unless event

  event_correct = event.created_at.to_i == progress.unlocked_at.to_i
  progress_correct = progress.created_at.to_i == progress.unlocked_at.to_i
  next if event_correct && progress_correct

  fixed += 1
  puts "#{commit ? "Fixing" : "Would fix"} XpEvent##{event.id} / UserNodeProgress##{progress.id} " \
       "(user_id=#{progress.user_id}, chain_node_id=#{progress.chain_node_id}): " \
       "#{event.created_at} -> #{progress.unlocked_at}"

  if commit
    event.update_column(:created_at, progress.unlocked_at)
    progress.update_column(:created_at, progress.unlocked_at)
  end
end

puts "#{commit ? "Fixed" : "Would fix"} #{fixed} event(s)."
