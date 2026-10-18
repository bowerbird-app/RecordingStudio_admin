# frozen_string_literal: true

require "test_helper"

class AdminIlikeFilterTest < ActiveSupport::TestCase
  setup do
    AdminAuditLog.delete_all
    ApiRequest.delete_all
    ApiError.delete_all
  end

  test "pattern escapes percent and underscore for postgres ILIKE" do
    ApiRequest.create!(path: "/v1/100%_done", method: "GET", status: 200, latency_ms: 1)
    ApiRequest.create!(path: "/v1/100XdoneY", method: "GET", status: 200, latency_ms: 1)

    matched = RecordingStudioAdmin::Filters::Ilike.apply(
      ApiRequest.all,
      "100%_done",
      columns: [:path]
    )

    assert_equal ["/v1/100%_done"], matched.order(:path).pluck(:path)
  end

  test "blank search leaves the relation unchanged" do
    ApiRequest.create!(path: "/v1/keep", method: "GET", status: 200, latency_ms: 1)
    relation = ApiRequest.all

    assert_equal relation.to_sql,
                 RecordingStudioAdmin::Filters::Ilike.apply(relation, "", columns: [:path]).to_sql
    assert_equal relation.to_sql,
                 RecordingStudioAdmin::Filters::Ilike.apply(relation, "   ", columns: [:path]).to_sql
    assert_equal 1, RecordingStudioAdmin::Filters::Ilike.apply(relation, nil, columns: [:path]).count
  end

  test "multiple columns match any declared field" do
    ApiError.create!(
      message: "timeout waiting",
      path: "/v1/orders",
      error_class: "TimeoutError",
      status: 500,
      created_at: 1.minute.ago,
      updated_at: 1.minute.ago
    )
    ApiError.create!(
      message: "other failure",
      path: "/v1/users",
      error_class: "RuntimeError",
      status: 500,
      created_at: 1.minute.ago,
      updated_at: 1.minute.ago
    )

    by_message = RecordingStudioAdmin::Filters::Ilike.apply(
      ApiError.all,
      "timeout",
      columns: %i[message path error_class]
    )
    by_path = RecordingStudioAdmin::Filters::Ilike.apply(
      ApiError.all,
      "users",
      columns: %i[message path error_class]
    )
    by_class = RecordingStudioAdmin::Filters::Ilike.apply(
      ApiError.all,
      "Runtime",
      columns: %i[message path error_class]
    )

    assert_equal ["TimeoutError"], by_message.pluck(:error_class)
    assert_equal ["RuntimeError"], by_path.pluck(:error_class)
    assert_equal ["RuntimeError"], by_class.pluck(:error_class)
  end

  test "admin activity logs screen search uses the shared helper against audit rows" do
    AdminAuditLog.create!(
      event_id: "evt-1",
      resource_key: "users",
      action_key: "create",
      outcome: "performed",
      actor_type: "User",
      actor_id: "1",
      record_type: "User",
      record_id: "1",
      request_id: "req-special%_value",
      occurred_at: Time.current
    )
    AdminAuditLog.create!(
      event_id: "evt-2",
      resource_key: "users",
      action_key: "update",
      outcome: "performed",
      actor_type: "User",
      actor_id: "2",
      record_type: "User",
      record_id: "2",
      request_id: "req-other",
      occurred_at: Time.current
    )

    filter = RecordingStudioAdmin::AdminActivityLogsScreen.table_value.filters.find { |item| item.key == :search }
    matched = filter.options[:apply].call(AdminAuditLog.all, "special%_value", nil)

    assert_equal ["evt-1"], matched.pluck(:event_id)
  end
end
