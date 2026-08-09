# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AwardXp do
  let(:user) { create(:user, total_xp: 10) }
  let(:chain) { create(:chain) }

  it 'creates an xp event and increments the user total atomically' do
    event = described_class.call(user: user, amount: 50, reason: 'chain_created', subject: chain)

    expect(event).to be_a(XpEvent)
    expect(event.amount).to eq(50)
    expect(event.reason).to eq('chain_created')
    expect(event.subject).to eq(chain)
    expect(user.reload.total_xp).to eq(60)
  end

  it 'accumulates across multiple calls' do
    described_class.call(user: user, amount: 5, reason: 'achievement_unlocked')
    described_class.call(user: user, amount: 5, reason: 'achievement_unlocked')

    expect(user.reload.total_xp).to eq(20)
    expect(user.xp_events.count).to eq(2)
  end

  it 'does nothing for a nil user' do
    expect { described_class.call(user: nil, amount: 50, reason: 'chain_created') }
      .not_to change(XpEvent, :count)
  end

  it 'does nothing for a zero amount' do
    expect { described_class.call(user: user, amount: 0, reason: 'chain_created') }
      .not_to change(XpEvent, :count)
    expect(user.reload.total_xp).to eq(10)
  end

  it 'works without a subject' do
    event = described_class.call(user: user, amount: 5, reason: 'achievement_unlocked')

    expect(event.subject).to be_nil
  end

  it 'backdates the event when occurred_at is given, for backfilling historical xp' do
    occurred_at = 3.days.ago

    event = described_class.call(user: user, amount: 5, reason: 'achievement_unlocked', occurred_at: occurred_at)

    expect(event.reload.created_at).to be_within(1.second).of(occurred_at)
  end
end
