class AwardChainNodeXp
  def self.call(chain, chain_nodes)
    new(chain, chain_nodes).call
  end

  def initialize(chain, chain_nodes)
    @chain = chain
    @chain_nodes = chain_nodes
  end

  def call
    return [] unless chain.creator

    chain_nodes.flat_map do |node|
      events = [award(XpRules::ACHIEVEMENT_ADDED_TO_CHAIN, "achievement_added", node)]
      events << award(XpRules::ACHIEVEMENT_NOTE_BONUS, "achievement_note", node) if node.note.present?
      events.compact
    end
  end

  private

  attr_reader :chain, :chain_nodes

  def award(amount, reason, subject)
    AwardXp.call(user: chain.creator, amount: amount, reason: reason, subject: subject)
  end
end
