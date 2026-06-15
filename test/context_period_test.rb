# frozen_string_literal: true

require "test_helper"

class ContextPeriodTest < Minitest::Test
  def reference_time
    Time.utc(2026, 6, 15, 12, 0, 0)
  end

  def test_period_label_for_duration_supports_days
    context = RecordingStudioAdmin::Context.new

    label = context.period_label(duration: 3.days, reference_time: reference_time)

    assert_equal "Last 3 days", label
  end

  def test_period_label_for_duration_supports_weeks
    context = RecordingStudioAdmin::Context.new

    label = context.period_label(duration: 4.weeks, reference_time: reference_time)

    assert_equal "Last 4 weeks", label
  end

  def test_period_label_uses_filter_preset_for_last_30_days
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 5, 16), Date.new(2026, 6, 15),
                                                                     :last_30_days)
    )

    label = context.period_label(reference_time: reference_time)

    assert_equal "Last 30 days", label
  end

  def test_period_label_derives_weeks_from_filter_window
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 5, 19), Date.new(2026, 6, 15), nil)
    )

    label = context.period_label(reference_time: reference_time)

    assert_equal "Last 4 weeks", label
  end
end
