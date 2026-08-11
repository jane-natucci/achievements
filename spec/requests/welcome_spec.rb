# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Welcome', type: :request do
  it 'renders the landing page with links to the wizard and the main app' do
    get welcome_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Welcome to Achievement ChainZ.')
    expect(response.body).to include('Yeah, we swapped the S for a Z. Just like in the 90s')
    expect(response.body).to include(wizard_path)
    expect(response.body).to include(root_path)
  end
end
