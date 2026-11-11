# frozen_string_literal: true

require "test_helper"
require "active_support/testing/time_helpers"

class DateAxisLabelsTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @previous_zone = Time.zone
    Time.zone = "UTC"
    @original_load_path = I18n.load_path.dup
    ensure_gem_locale_loaded!
    travel_to Time.zone.local(2026, 11, 11)
  end

  def teardown
    travel_back
    Time.zone = @previous_zone
    I18n.load_path = @original_load_path
    I18n.reload!
  end

  def test_hour_labels_repeat_the_day_only_when_the_date_changes
    times = [
      Time.zone.local(2026, 11, 12, 15),
      Time.zone.local(2026, 11, 12, 16),
      Time.zone.local(2026, 11, 13, 0),
      Time.zone.local(2026, 11, 13, 1)
    ]

    assert_equal ["Nov 12 3pm", "4pm", "Nov 13 12am", "1am"], labels(times, bucket: :hour)
  end

  def test_a_single_hour_includes_the_day_and_skips_the_year
    time = Time.zone.local(2025, 6, 15, 10)

    assert_equal ["Jun 15 10am"], labels([time], bucket: :hour)
  end

  def test_day_labels_in_the_current_year_omit_the_year
    times = [Time.zone.local(2026, 11, 12), Time.zone.local(2026, 11, 13)]

    assert_equal ["Nov 12", "Nov 13"], labels(times, bucket: :day)
  end

  def test_day_labels_in_another_year_put_the_year_on_the_first_label_only
    times = [Date.new(2025, 11, 12), Date.new(2025, 11, 13)]

    assert_equal ["Nov 12 2025", "Nov 13"], labels(times, bucket: :day)
  end

  def test_day_labels_add_the_year_when_the_year_changes
    times = [
      Time.zone.local(2026, 12, 30),
      Time.zone.local(2026, 12, 31),
      Time.zone.local(2027, 1, 1),
      Time.zone.local(2027, 1, 2)
    ]

    assert_equal ["Dec 30", "Dec 31", "Jan 1 2027", "Jan 2"], labels(times, bucket: :day)
  end

  def test_week_axis_labels_match_day_labels
    times = [Time.zone.local(2026, 11, 10), Time.zone.local(2025, 11, 10)]

    assert_equal ["Nov 10", "Nov 10 2025"], labels(times, bucket: :week, form: :axis)
  end

  def test_week_tooltips_prefix_the_axis_label
    current_year = [Time.zone.local(2026, 11, 10)]
    other_year = [Time.zone.local(2025, 11, 10)]
    rollover = [Time.zone.local(2026, 12, 31), Time.zone.local(2027, 1, 1)]

    assert_equal ["Week of Nov 10"], labels(current_year, bucket: :week, form: :tooltip)
    assert_equal ["Week of Nov 10 2025"], labels(other_year, bucket: :week, form: :tooltip)
    assert_equal ["Week of Dec 31", "Week of Jan 1 2027"], labels(rollover, bucket: :week, form: :tooltip)
  end

  def test_month_labels_keep_the_year_on_the_first_point_january_and_a_year_change
    rollover = [
      Time.zone.local(2026, 11, 1),
      Time.zone.local(2026, 12, 1),
      Time.zone.local(2027, 1, 1)
    ]
    current_year = [
      Time.zone.local(2026, 1, 1),
      Time.zone.local(2026, 2, 1),
      Time.zone.local(2026, 3, 1),
      Time.zone.local(2026, 4, 1)
    ]

    assert_equal ["Nov 2026", "Dec", "Jan 2027"], labels(rollover, bucket: :month)
    assert_equal ["Jan 2026", "Feb", "Mar", "Apr"], labels(current_year, bucket: :month)
    assert_equal ["Nov 2026", "Dec", "Jan 2027"], labels(rollover, bucket: :month, form: :tooltip)
  end

  def test_year_labels_are_the_four_digit_year
    times = [Time.zone.local(2026, 6, 1), Time.zone.local(2027, 1, 1)]

    assert_equal %w[2026 2027], labels(times, bucket: :year, form: :tooltip)
  end

  def test_empty_input_returns_an_empty_array
    assert_equal [], labels([])
  end

  def test_a_single_day_follows_the_first_label_rule
    assert_equal ["Nov 12"], labels([Time.zone.local(2026, 11, 12)], bucket: :day)
    assert_equal ["Nov 12 2025"], labels([Time.zone.local(2025, 11, 12)], bucket: :day)
  end

  def test_keeps_input_order_and_does_not_mutate_the_list
    times = [Time.zone.local(2026, 11, 13), "2026-11-12"].freeze

    assert_equal ["Nov 13", "Nov 12"], labels(times, bucket: "day")
    assert_equal [Time.zone.local(2026, 11, 13), "2026-11-12"], times
  end

  def test_an_unknown_bucket_labels_as_day
    times = [Time.zone.local(2026, 11, 12), Time.zone.local(2026, 11, 13)]

    assert_equal ["Nov 12", "Nov 13"], labels(times, bucket: :quarter)
  end

  def test_an_unknown_form_raises
    assert_raises(ArgumentError) do
      labels([Time.zone.local(2026, 11, 12)], form: :hover)
    end
  end

  private

  def labels(times, bucket: :day, form: :axis)
    RecordingStudioAdmin::DateAxisLabels.call(times, bucket: bucket, form: form)
  end

  def ensure_gem_locale_loaded!
    locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    expanded = File.expand_path(locale_path)
    loaded = I18n.load_path.map { |path| File.expand_path(path) }
    I18n.load_path << locale_path unless loaded.include?(expanded)
    I18n.reload!
  end
end
