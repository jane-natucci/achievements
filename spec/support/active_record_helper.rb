# frozen_string_literal: true

module ActiveRecordHelper
  def expect_no_sql_called
    queries_executed = 0
    ActiveSupport::Notifications.subscribed(
      ->(*args) { queries_executed += 1 if args[0] == 'sql.active_record' }
    ) do
      yield
      # Ensure that no queries were executed
      expect(queries_executed).to eq(0)
    end
  end

  def count_sql_queries
    queries_executed = 0
    ActiveSupport::Notifications.subscribed(
      ->(*args) { queries_executed += 1 if args[0] == 'sql.active_record' }
    ) do
      yield
    end
    queries_executed
  end
end

RSpec.configure do |config|
  config.include ActiveRecordHelper
end
