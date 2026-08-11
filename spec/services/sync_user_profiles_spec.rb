# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncUserProfiles do
  subject(:call) { described_class.call }

  let!(:alice) { create(:user, display_name: 'Old Alice', avatar_url: 'https://example.com/old-alice.jpg') }
  let!(:bob) { create(:user, display_name: 'Old Bob', avatar_url: 'https://example.com/old-bob.jpg') }

  def stub_summaries(*summaries)
    allow(Steam::User).to receive(:summaries).and_return(summaries)
  end

  it "updates each user's display name and avatar from Steam" do
    stub_summaries(
      { 'steamid' => alice.steam_id, 'personaname' => 'New Alice', 'avatarfull' => 'https://example.com/new-alice.jpg' },
      { 'steamid' => bob.steam_id, 'personaname' => 'New Bob', 'avatarfull' => 'https://example.com/new-bob.jpg' }
    )

    call

    expect(alice.reload.display_name).to eq('New Alice')
    expect(alice.avatar_url).to eq('https://example.com/new-alice.jpg')
    expect(bob.reload.display_name).to eq('New Bob')
    expect(bob.avatar_url).to eq('https://example.com/new-bob.jpg')
  end

  it 'falls back through avatarmedium and avatar when avatarfull is missing' do
    stub_summaries({ 'steamid' => alice.steam_id, 'personaname' => 'Alice', 'avatarmedium' => 'https://example.com/medium.jpg' })

    call

    expect(alice.reload.avatar_url).to eq('https://example.com/medium.jpg')
  end

  it 'leaves users untouched when Steam has no summary for them' do
    stub_summaries({ 'steamid' => alice.steam_id, 'personaname' => 'New Alice', 'avatarfull' => 'https://example.com/new-alice.jpg' })

    call

    expect(bob.reload.display_name).to eq('Old Bob')
  end

  it 'batches lookups in groups of at most 100 steamids' do
    create_list(:user, 150)
    seen_batch_sizes = []
    allow(Steam::User).to receive(:summaries) do |steamids|
      seen_batch_sizes << steamids.size
      []
    end

    call

    expect(seen_batch_sizes).to all(be <= 100)
    expect(seen_batch_sizes.sum).to eq(152) # alice + bob + 150 created
  end
end
