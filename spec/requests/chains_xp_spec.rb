# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chains XP on edit', type: :request do
  let(:game) { create(:game) }
  let!(:achievement_a) { create(:achievement, game: game) }
  let!(:achievement_b) { create(:achievement, game: game) }
  let!(:achievement_c) { create(:achievement, game: game) }
  let(:user) { create(:user) }

  before do
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  def selected_ids_json(achievements_with_notes)
    achievements_with_notes.map { |achievement, note| { id: achievement.id, note: note } }.to_json
  end

  it 'awards achievement-added xp only for genuinely new achievements, never re-awarding creation xp' do
    post chains_path, params: {
      chain: {
        title: 'My Chain', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, nil], [achievement_b, nil]])
      }
    }
    chain = Chain.last
    xp_after_create = user.reload.total_xp
    expect(xp_after_create).to eq(XpRules::CHAIN_CREATED + (2 * XpRules::ACHIEVEMENT_ADDED_TO_CHAIN))

    patch chain_path(chain), params: {
      chain: {
        title: 'My Chain', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, nil], [achievement_b, nil], [achievement_c, 'a note']])
      }
    }

    expected_new_xp = XpRules::ACHIEVEMENT_ADDED_TO_CHAIN + XpRules::ACHIEVEMENT_NOTE_BONUS
    expect(user.reload.total_xp).to eq(xp_after_create + expected_new_xp)
    expect(user.xp_events.where(reason: 'chain_created').count).to eq(1)
    expect(user.xp_events.where(reason: 'achievement_added').count).to eq(3)
  end

  it 'awards a note bonus for adding a note to an already-existing achievement in the chain' do
    post chains_path, params: {
      chain: {
        title: 'My Chain', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, nil], [achievement_b, nil]])
      }
    }
    chain = Chain.last
    xp_after_create = user.reload.total_xp

    patch chain_path(chain), params: {
      chain: {
        title: 'My Chain', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, 'finally wrote this down'], [achievement_b, nil]])
      }
    }

    expect(user.reload.total_xp).to eq(xp_after_create + XpRules::ACHIEVEMENT_NOTE_BONUS)
    expect(user.xp_events.where(reason: 'achievement_note').count).to eq(1)
    expect(user.xp_events.where(reason: 'achievement_added').count).to eq(2) # only from creation, none from this edit

    # editing the chain again without changing that note doesn't re-award the bonus
    xp_after_note = user.reload.total_xp
    patch chain_path(chain), params: {
      chain: {
        title: 'My Chain, Renamed', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, 'finally wrote this down'], [achievement_b, nil]])
      }
    }

    expect(user.reload.total_xp).to eq(xp_after_note)
    expect(user.xp_events.where(reason: 'achievement_note').count).to eq(1)
  end

  it 'awards nothing when an edit does not add any new achievements' do
    post chains_path, params: {
      chain: {
        title: 'My Chain', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, nil]])
      }
    }
    chain = Chain.last
    xp_after_create = user.reload.total_xp

    patch chain_path(chain), params: {
      chain: {
        title: 'My Chain, Renamed', game_id: game.id,
        selected_achievement_ids: selected_ids_json([[achievement_a, nil]])
      }
    }

    expect(user.reload.total_xp).to eq(xp_after_create)
  end
end
