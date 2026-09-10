# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = Rails.application.credentials.sentry_dsn
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Was 1.0 (every request/job traced) -- dropped after hitting 80% of the
  # org's monthly reserved span quota with pay-as-you-go disabled (Sentry
  # just silently drops spans past 100%, no overage risk, but losing
  # tracing data near the end of every month isn't great either). Covers
  # both achievements-web and achievements-sidekiq -- same initializer,
  # same codebase, different container command.
  config.traces_sample_rate = 0.1

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true
end
