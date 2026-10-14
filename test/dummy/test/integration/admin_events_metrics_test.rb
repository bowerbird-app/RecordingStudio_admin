# frozen_string_literal: true

require "test_helper"

class AdminEventsMetricsTest < ActiveSupport::TestCase
  setup do
    AdminAuditLog.delete_all
    @day = Time.utc(2025, 3, 5, 12)
    log!("users", "update", @day)
    log!("users", "update", @day + 1.hour)
    log!("pages", "destroy", @day + 1.day, outcome: "failed")
    log!("pages", "destroy", @day - 30.days)
  end

  test "admin_events.over_time counts audit rows by occurred_at" do
    result = execute("admin_events.over_time", **window)
    values = result.data.to_h { |row| [ row[:date], row[:value] ] }

    assert_equal 2, values["2025-03-05"]
    assert_equal 1, values["2025-03-06"]
    assert_equal 3, values.values.sum
  end

  test "admin_events.over_time groups by action and rejects other fields" do
    %w[action_key resource_key outcome].each do |group|
      execute("admin_events.over_time", **window, group_by: group)
    end
    assert_raises(RecordingStudioMetrics::Errors::InvalidGroupBy) do
      execute("admin_events.over_time", **window, group_by: "actor_id")
    end

    metadata = RecordingStudioMetrics.find("admin_events.over_time").catalog_metadata
    assert_equal "count", metadata[:unit]
    assert_equal "Admin actions over time", metadata[:title]
    assert_equal %i[action_key resource_key outcome], metadata[:group_by]
  end

  private

  def window
    { interval: :day, start_at: Time.utc(2025, 3, 5), end_at: Time.utc(2025, 3, 7) }
  end

  def log!(resource_key, action_key, occurred_at, outcome: "performed")
    AdminAuditLog.create!(event_id: SecureRandom.uuid, resource_key: resource_key, action_key: action_key,
                          outcome: outcome, occurred_at: occurred_at, metadata: {})
  end

  def execute(identifier, **params)
    RecordingStudioMetrics.execute(
      identifier,
      context: RecordingStudioMetrics::Context.new(system: true, scope: :site, site_authorized: true, timezone: "UTC"),
      cache: false,
      **params
    )
  end
end
