# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportSteamGame do
  subject(:call) { described_class.call(app_id, name: name, icon_hash: icon_hash) }

  let(:app_id) { 100 }
  let(:name) { 'Some Game' }
  let(:icon_hash) { 'abc123' }

  def schema_with_achievements(count)
    {
      'gameName' => 'Schema Game Name',
      'availableGameStats' => {
        'achievements' => Array.new(count) do |n|
          {
            'name' => "ach_#{n}",
            'displayName' => "Achievement #{n}",
            'description' => "Do the thing #{n}",
            'icon' => 'unlocked.jpg',
            'icongray' => 'locked.jpg',
            'hidden' => 0
          }
        end
      }
    }
  end

  it 'creates the game and its achievements from the Steam schema' do
    allow(Steam::UserStats).to receive(:game_schema).with(app_id).and_return(schema_with_achievements(2))

    expect { call }.to change(Game, :count).by(1).and change(Achievement, :count).by(2)

    game = Game.find_by(steam_app_id: app_id)
    expect(game.name).to eq('Some Game')
    expect(game.icon).to eq('https://media.steampowered.com/steamcommunity/public/images/apps/100/abc123.jpg')
    expect(game.achievements.pluck(:steam_api_name)).to match_array(%w[ach_0 ach_1])
  end

  context 'when no name is given' do
    let(:name) { nil }

    it "falls back to the schema's game name" do
      allow(Steam::UserStats).to receive(:game_schema).with(app_id).and_return(schema_with_achievements(1))

      call

      expect(Game.find_by(steam_app_id: app_id).name).to eq('Schema Game Name')
    end
  end

  it 'returns the existing game without calling Steam again when already present' do
    existing = create(:game, steam_app_id: app_id)

    expect(Steam::UserStats).not_to receive(:game_schema)
    expect(call).to eq(existing)
  end

  it 'imports nothing when the schema has no achievements' do
    allow(Steam::UserStats).to receive(:game_schema).with(app_id).and_return(schema_with_achievements(0))

    expect { call }.not_to change(Game, :count)
  end

  it 'imports nothing when Steam has no schema at all for the app' do
    allow(Steam::UserStats).to receive(:game_schema).with(app_id).and_return(nil)

    expect { call }.not_to change(Game, :count)
  end
end
