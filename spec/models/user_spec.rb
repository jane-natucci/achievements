# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#online?' do
    it 'is false when last_seen_at has never been set' do
      user = create(:user, last_seen_at: nil)

      expect(user.online?).to be(false)
    end

    it 'is true within the online window' do
      user = create(:user, last_seen_at: 30.seconds.ago)

      expect(user.online?).to be(true)
    end

    it 'is false once the online window has passed' do
      user = create(:user, last_seen_at: described_class::ONLINE_WINDOW.ago - 1.second)

      expect(user.online?).to be(false)
    end
  end
end
