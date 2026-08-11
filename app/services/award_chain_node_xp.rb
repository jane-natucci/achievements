class AwardChainNodeXp
  # new_nodes defaults to chain_nodes: when creating a chain, every node
  # passed in is new. On edit, the caller passes only the subset that's
  # genuinely new so re-saving an existing achievement doesn't re-award it.
  #
  # Matched by id rather than object identity/previously_new_record? --
  # chain_nodes may be freshly reloaded from the DB (e.g. via chain.chain_nodes)
  # rather than the exact instances that were just saved.
  def self.call(chain, chain_nodes, new_nodes: chain_nodes)
    new(chain, chain_nodes, new_nodes).call
  end

  def initialize(chain, chain_nodes, new_nodes)
    @chain = chain
    @chain_nodes = chain_nodes
    @new_node_ids = new_nodes.map(&:id).to_set
  end

  def call
    return [] unless chain.creator

    chain_nodes.flat_map do |node|
      is_new = new_node_ids.include?(node.id)

      events = []
      events << award(XpRules::ACHIEVEMENT_ADDED_TO_CHAIN, "achievement_added", node) if is_new
      events << award(XpRules::ACHIEVEMENT_NOTE_BONUS, "achievement_note", node) if note_newly_set?(node, is_new)
      events.compact
    end
  end

  private

  attr_reader :chain, :chain_nodes, :new_node_ids

  # A new node's note is "newly set" simply by being present -- there's no
  # prior state to compare against. An existing node (edited into the chain
  # again) only earns the bonus when this save actually changed its note --
  # not on every re-save of a chain whose notes were already there.
  def note_newly_set?(node, is_new)
    return node.note.present? if is_new

    node.saved_change_to_note? && node.note.present?
  end

  def award(amount, reason, subject)
    AwardXp.call(user: chain.creator, amount: amount, reason: reason, subject: subject)
  end
end
