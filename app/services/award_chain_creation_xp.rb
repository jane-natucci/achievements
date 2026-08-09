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

    events.compact + AwardChainNodeXp.call(chain, chain.chain_nodes)
  end

  private

  attr_reader :chain

  def award(amount, reason, subject)
    AwardXp.call(user: chain.creator, amount: amount, reason: reason, subject: subject)
  end
end
