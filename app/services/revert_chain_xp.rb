# Cleans up XP history tied to a chain (and its chain_nodes) when that
# chain is deleted -- otherwise "Created X" / "Added Y to a chain" rows
# stick around in everyone's feed pointing at a chain that 404s, and
# total_xp stays inflated relative to what's actually still visible.
#
# Chains are soft-deleted (Discard::Model), so chain_nodes still exist at
# the point this runs -- it must be called before/alongside the discard,
# not after the chain (and its association data) would otherwise be gone.
class RevertChainXp
  CHAIN_REASONS = %w[chain_created chain_description chain_completed chain_favorited].freeze
  CHAIN_NODE_REASONS = %w[achievement_added achievement_note achievement_unlocked].freeze

  def self.call(chain)
    new(chain).call
  end

  def initialize(chain)
    @chain = chain
  end

  def call
    events.find_each do |event|
      event.user.decrement!(:total_xp, event.amount) if event.amount.positive?
      event.destroy!
    end
  end

  private

  attr_reader :chain

  def events
    chain_events = XpEvent.where(subject_type: "Chain", subject_id: chain.id, reason: CHAIN_REASONS)
    node_events = XpEvent.where(subject_type: "ChainNode", subject_id: chain.chain_nodes.select(:id), reason: CHAIN_NODE_REASONS)

    chain_events.or(node_events)
  end
end
