# frozen_string_literal: true

# Run with:
#   bin/rails runner script/create_freemans_journey_chain.rb
#
# Prerequisite:
# - Half-Life 2 and its achievements must already be imported into the database.

CHAIN_TITLE = "Freeman's Journey Through City 17"
CHAIN_DESCRIPTION = "A sample chain that follows Gordon Freeman's rise from City 17 escapee to Combine-breaker."
HALF_LIFE_2_APP_ID = 220

ACHIEVEMENT_TITLES_IN_ORDER = [
  "Trusty Hardware",
  "Malcontent",
  "Anchor's Aweigh!",
  "Heavy Weapons",
  "Zero-Point Energy",
  "Warden Freeman",
  "Follow Freeman",
  "Plaza Defender",
  "Fight the Power",
  "Giant Killer",
  "Singularity Collapse"
].freeze

game = Game.find_by!(steam_app_id: HALF_LIFE_2_APP_ID)

achievements = ACHIEVEMENT_TITLES_IN_ORDER.map do |title|
  game.achievements.find_by(title: title).tap do |achievement|
    next if achievement

    raise ActiveRecord::RecordNotFound, "Missing achievement '#{title}' for #{game.name}. Import the game's achievements first."
  end
end

chain = Chain.find_or_initialize_by(game: game, title: CHAIN_TITLE)
chain.description = CHAIN_DESCRIPTION
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

puts "Created sample chain '#{chain.title}' for #{game.name} with #{achievements.size} achievements."
