# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SteamOpenid do
  describe '.authorize_url' do
    it 'builds a Steam OpenID checkid_setup URL with the given return_to and realm' do
      url = described_class.authorize_url(return_to: 'https://example.com/callback', realm: 'https://example.com')

      expect(url).to start_with('https://steamcommunity.com/openid/login?')
      expect(url).to include('openid.mode=checkid_setup')
      expect(url).to include(CGI.escape('https://example.com/callback'))
      expect(url).to include(CGI.escape('https://example.com'))
    end
  end

  describe '.verify_steam_id' do
    let(:claimed_id) { 'https://steamcommunity.com/openid/id/76561199079570785' }
    let(:callback_params) { { 'openid.claimed_id' => claimed_id, 'openid.mode' => 'id_res', 'openid.sig' => 'abc' } }

    it "returns the steamid64 when Steam confirms the signature is valid" do
      response = instance_double(Net::HTTPResponse, body: "ns:http://specs.openid.net/auth/2.0\nis_valid:true\n")
      allow(Net::HTTP).to receive(:post_form).and_return(response)

      expect(described_class.verify_steam_id(callback_params)).to eq('76561199079570785')
    end

    it 'returns nil when Steam says the signature is invalid' do
      response = instance_double(Net::HTTPResponse, body: "ns:http://specs.openid.net/auth/2.0\nis_valid:false\n")
      allow(Net::HTTP).to receive(:post_form).and_return(response)

      expect(described_class.verify_steam_id(callback_params)).to be_nil
    end

    it 'returns nil without contacting Steam when the claimed_id is malformed' do
      expect(Net::HTTP).not_to receive(:post_form)

      bad_params = { 'openid.claimed_id' => 'https://evil.example.com/76561199079570785' }
      expect(described_class.verify_steam_id(bad_params)).to be_nil
    end

    it 'returns nil if the verification request itself raises' do
      allow(Net::HTTP).to receive(:post_form).and_raise(SocketError)

      expect(described_class.verify_steam_id(callback_params)).to be_nil
    end
  end
end
