# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SteamProfileLogin do
  describe '.call' do
    context 'with a blank profile URL' do
      it 'returns a failed result with a helpful error' do
        result = described_class.call('')

        expect(result).not_to be_success
        expect(result.error).to match(/valid Steam profile URL/)
      end
    end

    context 'with a raw SteamID64' do
      it 'resolves the profile without calling vanity_to_steamid' do
        allow(Steam::User).to receive(:summary).with('76561199079570785').and_return(
          'personaname' => 'Jane', 'avatarfull' => 'https://example.com/avatar.jpg'
        )

        result = described_class.call('76561199079570785')

        expect(result).to be_success
        expect(result.user.steam_id).to eq('76561199079570785')
        expect(result.user.display_name).to eq('Jane')
      end
    end

    context 'with a full profile URL' do
      it 'extracts the SteamID64 and upserts the user' do
        allow(Steam::User).to receive(:summary).with('76561199079570785').and_return(
          'personaname' => 'Jane', 'avatarmedium' => 'https://example.com/avatar-medium.jpg'
        )

        result = described_class.call('https://steamcommunity.com/profiles/76561199079570785/')

        expect(result).to be_success
        expect(result.user.avatar_url).to eq('https://example.com/avatar-medium.jpg')
      end
    end

    context 'with a vanity URL' do
      it 'resolves the vanity name to a SteamID64 first' do
        allow(Steam::User).to receive(:vanity_to_steamid).with('janedoe').and_return('76561199079570785')
        allow(Steam::User).to receive(:summary).with('76561199079570785').and_return('personaname' => 'Jane')

        result = described_class.call('https://steamcommunity.com/id/janedoe')

        expect(result).to be_success
        expect(result.user.steam_id).to eq('76561199079570785')
      end
    end

    context "when Steam can't find the profile" do
      it 'returns a failed result' do
        allow(Steam::User).to receive(:summary).with('76561199079570785').and_return(nil)

        result = described_class.call('76561199079570785')

        expect(result).not_to be_success
        expect(result.error).to match(/Could not load/)
      end
    end

    context 'when the Steam API raises' do
      it 'rescues and returns a failed result' do
        allow(Steam::User).to receive(:summary).and_raise(StandardError, 'network down')

        result = described_class.call('76561199079570785')

        expect(result).not_to be_success
        expect(result.error).to match(/network down/)
      end
    end
  end
end
