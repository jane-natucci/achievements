class AwardChainCreationXp
  def self.call(chain)
    new(chain).call
  end

  def initialize(chain)
    @chain = chain
  end

  def call
    return [] unless chain.creator

    events = []
    events << award(XpRules::CHAIN_CREATED, "chain_created", chain)
    events << award(XpRules::CHAIN_DESCRIPTION_BONUS, "chain_description", chain) if chain.description.present?

    chain.chain_nodes.each do |node|
      events << award(XpRules::ACHIEVEMENT_ADDED_TO_CHAIN, "achievement_added", node)
      events << award(XpRules::ACHIEVEMENT_NOTE_BONUS, "achievement_note", node) if node.note.present?
    end

    events.compact
  end

  private

  attr_reader :chain

  def award(amount, reason, subject)
    AwardXp.call(user: chain.creator, amount: amount, reason: reason, subject: subject)
  end
end
