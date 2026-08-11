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
      events = []
      events << award(XpRules::ACHIEVEMENT_ADDED_TO_CHAIN, "achievement_added", node) if node.previously_new_record?
      events << award(XpRules::ACHIEVEMENT_NOTE_BONUS, "achievement_note", node) if note_newly_set?(node)
      events.compact
    end
  end

  private

  attr_reader :chain, :chain_nodes

  # A brand-new node's note is "newly set" simply by being present. An
  # existing node (edited into the chain again) only earns the bonus when
  # this save actually changed its note -- not on every re-save of a chain
  # whose notes were already there.
  def note_newly_set?(node)
    return node.note.present? if node.previously_new_record?

    node.saved_change_to_note? && node.note.present?
  end

  def award(amount, reason, subject)
    AwardXp.call(user: chain.creator, amount: amount, reason: reason, subject: subject)
  end
end
