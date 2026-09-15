# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshGameAchievementCatalog do
  subject(:call) { described_class.call(game) }

  let(:game) { create(:game, steam_app_id: 100) }

  def schema_with(names)
    {
      'availableGameStats' => {
        'achievements' => names.map do |name|
          { 'name' => name, 'displayName' => name.titleize, 'description' => "Do #{name}",
            'icon' => "#{name}_unlocked.jpg", 'icongray' => "#{name}_locked.jpg", 'hidden' => 0 }
        end
      }
    }
  end

  it "adds achievements missing from the game's existing catalog" do
    create(:achievement, game: game, steam_api_name: 'already_known')
    allow(Steam::UserStats).to receive(:game_schema).with(game.steam_app_id)
      .and_return(schema_with(%w[already_known newly_added]))

    expect { call }.to change { game.achievements.count }.by(1)

    added = game.achievements.find_by(steam_api_name: 'newly_added')
    expect(added.title).to eq('Newly Added')
    expect(added.icon_unlocked).to eq('newly_added_unlocked.jpg')
  end

  it 'returns the count of achievements added' do
    allow(Steam::UserStats).to receive(:game_schema).with(game.steam_app_id)
      .and_return(schema_with(%w[one two three]))

    expect(call).to eq(3)
  end

  it "doesn't touch or duplicate an already-known achievement" do
    existing = create(:achievement, game: game, steam_api_name: 'already_known', title: 'Custom Title')
    allow(Steam::UserStats).to receive(:game_schema).with(game.steam_app_id)
      .and_return(schema_with(%w[already_known]))

    expect { call }.not_to change(Achievement, :count)
    expect(existing.reload.title).to eq('Custom Title')
  end

  it 'does nothing when Steam has no schema for the game' do
    allow(Steam::UserStats).to receive(:game_schema).with(game.steam_app_id).and_return(nil)

    expect { call }.not_to change(Achievement, :count)
    expect(call).to eq(0)
  end

  context 'for EU5 (steam_app_id 3450310)' do
    let(:game) { create(:game, steam_app_id: 3_450_310) }

    it "rewrites icon URLs off Steam's dead CDN domain" do
      allow(Steam::UserStats).to receive(:game_schema).with(game.steam_app_id).and_return(
        'availableGameStats' => { 'achievements' => [
          { 'name' => 'ach', 'displayName' => 'Ach', 'description' => 'd',
            'icon' => 'https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/3450310/abc.jpg',
            'icongray' => 'https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/3450310/def.jpg',
            'hidden' => 0 }
        ] }
      )

      call

      added = game.achievements.find_by(steam_api_name: 'ach')
      expect(added.icon_unlocked).to eq('https://shared.akamai.steamstatic.com/community_assets/images/apps/3450310/abc.jpg')
      expect(added.icon_locked).to eq('https://shared.akamai.steamstatic.com/community_assets/images/apps/3450310/def.jpg')
    end
  end
end
