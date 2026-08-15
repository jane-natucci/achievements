# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cookie consent banner', type: :request do
  before do
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  it 'shows the banner and skips Amplitude when no consent cookie is set yet' do
    get root_path

    expect(response.body).to include('cookie-banner')
    expect(response.body).not_to include('cdn.amplitude.com')
  end

  it 'loads Amplitude and hides the banner once consent is accepted' do
    get root_path, params: {}, headers: { 'Cookie' => 'cookie_consent=accepted' }

    expect(response.body).to include('cdn.amplitude.com')
    expect(response.body).not_to include('cookie-banner')
  end

  it 'skips Amplitude and hides the banner once consent is declined' do
    get root_path, params: {}, headers: { 'Cookie' => 'cookie_consent=declined' }

    expect(response.body).not_to include('cdn.amplitude.com')
    expect(response.body).not_to include('cookie-banner')
  end
end
