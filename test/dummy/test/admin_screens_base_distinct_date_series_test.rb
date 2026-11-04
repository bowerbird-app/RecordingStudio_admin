# frozen_string_literal: true

require "test_helper"

class AdminScreensBaseDistinctDateSeriesTest < ActiveSupport::TestCase
  test "distinct_date_series counts unique column values per day without interpolating SQL" do
    UserActivity.delete_all
    day = Time.zone.parse("2026-11-03 12:00:00")
    UserActivity.create!(email: "one@example.com", action: "signed_in", status: "success", created_at: day, updated_at: day)
    UserActivity.create!(email: "one@example.com", action: "exported_report", status: "success", created_at: day + 1.hour, updated_at: day + 1.hour)
    UserActivity.create!(email: "two@example.com", action: "signed_in", status: "success", created_at: day + 2.hours, updated_at: day + 2.hours)

    sqls = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sqls << payload[:sql].to_s
    end

    series = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      AdminScreens::Base.distinct_date_series(UserActivity.all, distinct_field: :email, bucket: :day)
    end

    assert_equal 1, series.size
    assert_equal 2, series.first[:y]
    assert(sqls.any? { |sql| sql.include?('COUNT(DISTINCT "user_activities"."email")') })
  end
end
