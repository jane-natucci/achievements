# frozen_string_literal: true

# Run with:
#   bin/rails runner script/reorder_victoria_3_chain_by_unlock_rate.rb
#
# Reorders "All Victoria 3 Achievements" so the most commonly unlocked
# achievements (by % of registered users who've unlocked them) come first,
# rarest last -- rather than Steam's raw schema order. Only rewrites the
# chain's sequence edges; chain_node rows (and their progress/XP history)
# are untouched.

CHAIN_TITLE = "All Victoria 3 Achievements"

chain = Chain.find_by!(title: CHAIN_TITLE)
total_users = User.count.to_f
raise "No registered users to compute unlock rates from" if total_users.zero?

unlock_counts = UserAchievementUnlock.where(achievement_id: chain.chain_nodes.select(:ref_id))
                                      .group(:achievement_id)
                                      .count

ordered_nodes = chain.chain_nodes.includes(:achievement).to_a.sort_by do |node|
  -(unlock_counts[node.ref_id] || 0)
end

ActiveRecord::Base.transaction do
  chain.chain_edges.delete_all

  ordered_nodes.each_cons(2) do |from_node, to_node|
    chain.chain_edges.create!(from_node: from_node.id, to_node: to_node.id, edge_type: "sequence")
  end
end

puts "Reordered #{ordered_nodes.size} achievements in '#{chain.title}' by unlock rate (most to least)."
ordered_nodes.first(5).each do |node|
  pct = ((unlock_counts[node.ref_id] || 0) / total_users * 100).round(1)
  puts "  #{pct}% - #{node.achievement.title}"
end
