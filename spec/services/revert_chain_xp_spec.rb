# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RevertChainXp do
  subject(:call) { described_class.call(chain) }

  let(:creator) { create(:user, total_xp: 1000) }
  let(:chain) { create(:chain, creator: creator, description: 'A great chain') }
  let!(:node_a) { create(:chain_node, chain: chain) }
  let!(:node_b) { create(:chain_node, chain: chain) }

  it 'destroys chain-level xp events and deducts their amount from total_xp' do
    AwardXp.call(user: creator, amount: 50, reason: 'chain_created', subject: chain)
    AwardXp.call(user: creator, amount: 25, reason: 'chain_description', subject: chain)

    expect { call }.to change { creator.reload.total_xp }.by(-75)
    expect(XpEvent.where(subject: chain).count).to eq(0)
  end

  it "destroys chain_node-level xp events (achievement_added/note/unlocked) and deducts them from whichever user earned them" do
    AwardXp.call(user: creator, amount: 5, reason: 'achievement_added', subject: node_a)
    AwardXp.call(user: creator, amount: 3, reason: 'achievement_note', subject: node_a)
    other_user = create(:user)
    AwardXp.call(user: other_user, amount: 5, reason: 'achievement_unlocked', subject: node_b)

    creator_xp_before = creator.reload.total_xp
    other_user_xp_before = other_user.reload.total_xp

    call

    expect(creator.reload.total_xp).to eq(creator_xp_before - 8)
    expect(other_user.reload.total_xp).to eq(other_user_xp_before - 5)
    expect(XpEvent.where(subject: node_a).count).to eq(0)
    expect(XpEvent.where(subject: node_b).count).to eq(0)
  end

  it 'destroys zero-xp chain_favorited events without changing total_xp' do
    fan = create(:user, total_xp: 100)
    AwardXp.call(user: fan, amount: 0, reason: 'chain_favorited', subject: chain)

    expect { call }.not_to(change { fan.reload.total_xp })
    expect(XpEvent.where(subject: chain, reason: 'chain_favorited').count).to eq(0)
  end

  it "doesn't touch xp events for other chains or unrelated reasons" do
    other_chain = create(:chain, creator: creator)
    AwardXp.call(user: creator, amount: 50, reason: 'chain_created', subject: other_chain)
    AwardXp.call(user: creator, amount: 100, reason: 'profile_created')

    expect { call }.not_to(change { creator.reload.total_xp })
    expect(XpEvent.where(subject: other_chain).count).to eq(1)
    expect(creator.xp_events.where(reason: 'profile_created').count).to eq(1)
  end

  it 'works on an already-discarded chain (chain_nodes still resolve)' do
    AwardXp.call(user: creator, amount: 5, reason: 'achievement_added', subject: node_a)
    chain.discard!

    expect { call }.to change { creator.reload.total_xp }.by(-5)
  end
end
