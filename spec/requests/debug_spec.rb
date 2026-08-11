# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Debug', type: :request do
  it 'renders links to Sentry, Datadog, and Sidekiq' do
    get debug_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('sentry.io')
    expect(response.body).to include('datadoghq.eu')
    expect(response.body).to include('/sidekiq')
  end
end
