namespace :xp do
  desc "Award missing achievement-unlock XP for already-completed progress, and missing profile-creation XP for existing users"
  task backfill: :environment do
    unlocks_awarded = 0

    UserNodeProgress.where(status: "completed").find_each do |progress|
      already_awarded = XpEvent.exists?(
        user_id: progress.user_id,
        reason: "achievement_unlocked",
        subject_type: "ChainNode",
        subject_id: progress.chain_node_id
      )
      next if already_awarded

      AwardXp.call(
        user: progress.user,
        amount: XpRules::ACHIEVEMENT_UNLOCKED,
        reason: "achievement_unlocked",
        subject: progress.chain_node,
        occurred_at: progress.created_at
      )
      unlocks_awarded += 1
    end

    profiles_awarded = 0

    User.find_each do |user|
      next if XpEvent.exists?(user_id: user.id, reason: "profile_created")

      AwardXp.call(user: user, amount: XpRules::PROFILE_CREATED, reason: "profile_created", occurred_at: user.created_at)
      profiles_awarded += 1
    end

    puts "Backfilled #{unlocks_awarded} achievement-unlock xp event(s) and #{profiles_awarded} profile-creation xp event(s)."
  end
end
