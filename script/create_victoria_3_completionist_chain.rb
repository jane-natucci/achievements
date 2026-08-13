# frozen_string_literal: true

# Run with:
#   bin/rails runner script/create_victoria_3_completionist_chain.rb
#
# Creates a "collect them all" chain containing every Victoria 3 achievement,
# in ascending id order (matches the order they were imported from Steam's
# game schema) -- not a curated/gameplay-ordered chain, just a demo.

CHAIN_TITLE = "All Victoria 3 Achievements"
CHAIN_DESCRIPTION = "Every achievement in Victoria 3, just for the sake of it."
CREATOR_DISPLAY_NAME = "Jane"

game = Game.find_by!(name: "Victoria 3")
creator = User.find_by!(display_name: CREATOR_DISPLAY_NAME)
achievements = game.achievements.order(:id)

raise "No achievements found for #{game.name}" if achievements.empty?

chain = Chain.find_or_initialize_by(game: game, title: CHAIN_TITLE)
was_new_chain = chain.new_record?
chain.description = CHAIN_DESCRIPTION
chain.creator = creator
chain.visibility ||= "public"

ActiveRecord::Base.transaction do
  chain.save!
  chain.chain_edges.delete_all
  chain.chain_nodes.delete_all

  created_nodes = achievements.map do |achievement|
    chain.chain_nodes.create!(ref_id: achievement.id)
  end

  created_nodes.each_cons(2) do |from_node, to_node|
    chain.chain_edges.create!(
      from_node: from_node.id,
      to_node: to_node.id,
      edge_type: "sequence"
    )
  end
end

AwardChainCreationXp.call(chain.reload) if was_new_chain
SyncUserAchievementProgress.call(creator)

puts "Created chain '#{chain.title}' for #{game.name} with #{achievements.size} achievements (creator: #{creator.display_name})."
