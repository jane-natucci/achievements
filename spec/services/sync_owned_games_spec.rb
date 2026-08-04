# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncOwnedGames do
  subject(:call) { described_class.call(user) }

  let(:user) { create(:user) }

  def owned_game(appid, playtime_forever:, name: "Game #{appid}", icon_hash: 'abc123')
    { 'appid' => appid, 'playtime_forever' => playtime_forever, 'name' => name, 'img_icon_url' => icon_hash }
  end

  def schema_with_achievements(count)
    {
      'gameName' => 'Some Game',
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

  it 'creates a game and its achievements when playtime clears the threshold and the game has achievements' do
    allow(Steam::Player).to receive(:owned_games).with(user.steam_id, anything).and_return(
      'games' => [owned_game(100, playtime_forever: 180)]
    )
    allow(Steam::UserStats).to receive(:game_schema).with(100).and_return(schema_with_achievements(3))

    expect { call }.to change(Game, :count).by(1).and change(Achievement, :count).by(3)

    game = Game.find_by(steam_app_id: 100)
    expect(game.name).to eq('Game 100')
    expect(game.icon).to eq('https://media.steampowered.com/steamcommunity/public/images/apps/100/abc123.jpg')
    expect(game.achievements.pluck(:steam_api_name)).to match_array(%w[ach_0 ach_1 ach_2])
  end

  it 'skips games under the playtime threshold' do
    allow(Steam::Player).to receive(:owned_games).with(user.steam_id, anything).and_return(
      'games' => [owned_game(200, playtime_forever: 60)]
    )

    expect(Steam::UserStats).not_to receive(:game_schema)
    expect { call }.not_to change(Game, :count)
  end

  it 'skips games that have no achievements in their schema' do
    allow(Steam::Player).to receive(:owned_games).with(user.steam_id, anything).and_return(
      'games' => [owned_game(300, playtime_forever: 300)]
    )
    allow(Steam::UserStats).to receive(:game_schema).with(300).and_return(schema_with_achievements(0))

    expect { call }.not_to change(Game, :count)
  end

  it 'skips games already present in the catalog' do
    create(:game, steam_app_id: 400)
    allow(Steam::Player).to receive(:owned_games).with(user.steam_id, anything).and_return(
      'games' => [owned_game(400, playtime_forever: 300)]
    )

    expect(Steam::UserStats).not_to receive(:game_schema)
    expect { call }.not_to change(Game, :count)
  end

  it 'continues past a single game raising an error' do
    allow(Steam::Player).to receive(:owned_games).with(user.steam_id, anything).and_return(
      'games' => [owned_game(500, playtime_forever: 300), owned_game(501, playtime_forever: 300)]
    )
    allow(Steam::UserStats).to receive(:game_schema).with(500).and_raise(StandardError, 'boom')
    allow(Steam::UserStats).to receive(:game_schema).with(501).and_return(schema_with_achievements(1))

    expect { call }.to change(Game, :count).by(1)
    expect(Game.find_by(steam_app_id: 500)).to be_nil
    expect(Game.find_by(steam_app_id: 501)).to be_present
  end
end
