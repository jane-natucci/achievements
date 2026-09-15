# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckEu5IconUrls do
  subject(:call) { described_class.call }

  let(:eu5) { create(:game, steam_app_id: described_class::EU5_STEAM_APP_ID) }

  def fake_response(code)
    instance_double(Net::HTTPResponse, code: code.to_s)
  end

  it 'does nothing when every EU5 icon URL resolves' do
    create(:achievement, game: eu5,
      icon_unlocked: 'https://shared.akamai.steamstatic.com/community_assets/images/apps/3450310/a.jpg',
      icon_locked: 'https://shared.akamai.steamstatic.com/community_assets/images/apps/3450310/a_gray.jpg')
    allow(Net::HTTP).to receive(:start).and_return(fake_response(200))

    expect(Rails.logger).not_to receive(:error)
    call
  end

  it 'logs when an EU5 icon URL is broken' do
    create(:achievement, game: eu5,
      icon_unlocked: 'https://shared.akamai.steamstatic.com/community_assets/images/apps/3450310/broken.jpg')
    allow(Net::HTTP).to receive(:start).and_return(fake_response(404))

    expect(Rails.logger).to receive(:error) do |message|
      expect(message).to include('broken.jpg')
      expect(message).to include('1 broken')
    end
    call
  end

  it "ignores achievements from other games" do
    other_game = create(:game, steam_app_id: 999)
    create(:achievement, game: other_game, icon_unlocked: 'https://steamcdn-a.akamaihd.net/broken.jpg')

    expect(Net::HTTP).not_to receive(:start)
    expect(call).to be_nil
  end

  it 'does nothing when EU5 has not been imported at all' do
    expect(Net::HTTP).not_to receive(:start)
    expect(call).to be_nil
  end
end
