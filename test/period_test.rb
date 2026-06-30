# frozen_string_literal: true

require "test_helper"

class PeriodTest < Minitest::Test
  def setup
    @reference_time = Time.utc(2026, 6, 15, 12, 0, 0)
    @reference_date = @reference_time.to_date
  end

  def test_label_uses_explicit_label_when_present
    period = RecordingStudioAdmin::Period.new(amount: 7, unit: :day, explicit_label: "This week")

    assert_equal "This week", period.label
  end

  def test_label_pluralizes_and_singularizes_unit
    assert_equal "Last 1 day", RecordingStudioAdmin::Period.new(amount: 1, unit: :day).label
    assert_equal "Last 2 days", RecordingStudioAdmin::Period.new(amount: 2, unit: :day).label
  end

  def test_from_duration_supports_each_supported_unit
    month_duration = Struct.new(:parts).new([[:months, 1]])
    year_duration = Struct.new(:parts).new([[:years, 1]])

    day_period = RecordingStudioAdmin::Period.from_duration(3.days, reference_time: @reference_time)
    week_period = RecordingStudioAdmin::Period.from_duration(2.weeks, reference_time: @reference_time)
    month_period = RecordingStudioAdmin::Period.from_duration(month_duration, reference_time: @reference_time)
    year_period = RecordingStudioAdmin::Period.from_duration(year_duration, reference_time: @reference_time)

    assert_equal :day, day_period.unit
    assert_equal Date.new(2026, 6, 12), day_period.start_date
    assert_equal :last_3_days, day_period.preset_key

    assert_equal :week, week_period.unit
    assert_equal Date.new(2026, 6, 1), week_period.start_date
    assert_equal :last_2_weeks, week_period.preset_key

    assert_equal :month, month_period.unit
    assert_equal Date.new(2026, 5, 15), month_period.start_date
    assert_equal :last_1_months, month_period.preset_key

    assert_equal :year, year_period.unit
    assert_equal Date.new(2025, 6, 15), year_period.start_date
    assert_equal :last_1_years, year_period.preset_key
  end

  def test_from_duration_returns_nil_for_non_duration_values
    assert_nil RecordingStudioAdmin::Period.from_duration("3 days", reference_time: @reference_time)
    assert_nil RecordingStudioAdmin::Period.from_duration(1.day + 2.hours, reference_time: @reference_time)
  end

  def test_from_preset_key_handles_quick_presets
    today = RecordingStudioAdmin::Period.from_preset_key(:today, reference_date: @reference_date)
    yesterday = RecordingStudioAdmin::Period.from_preset_key(:yesterday, reference_date: @reference_date)
    this_week = RecordingStudioAdmin::Period.from_preset_key(:this_week, reference_date: @reference_date)
    last_week = RecordingStudioAdmin::Period.from_preset_key(:last_week, reference_date: @reference_date)
    this_month = RecordingStudioAdmin::Period.from_preset_key(:this_month, reference_date: @reference_date)
    last_month = RecordingStudioAdmin::Period.from_preset_key(:last_month, reference_date: @reference_date)
    this_year = RecordingStudioAdmin::Period.from_preset_key(:this_year, reference_date: @reference_date)
    last_year = RecordingStudioAdmin::Period.from_preset_key(:last_year, reference_date: @reference_date)

    assert_equal "Today", today.label
    assert_equal [Date.new(2026, 6, 15), Date.new(2026, 6, 15)], [today.start_date, today.end_date]

    assert_equal "Yesterday", yesterday.label
    assert_equal [Date.new(2026, 6, 14), Date.new(2026, 6, 14)], [yesterday.start_date, yesterday.end_date]

    assert_equal "This week", this_week.label
    assert_equal [Date.new(2026, 6, 15), Date.new(2026, 6, 15)], [this_week.start_date, this_week.end_date]

    assert_equal "Last week", last_week.label
    assert_equal [Date.new(2026, 6, 8), Date.new(2026, 6, 14)], [last_week.start_date, last_week.end_date]

    assert_equal "This month", this_month.label
    assert_equal [Date.new(2026, 6, 1), Date.new(2026, 6, 15)], [this_month.start_date, this_month.end_date]

    assert_equal "Last month", last_month.label
    assert_equal [Date.new(2026, 5, 1), Date.new(2026, 5, 31)], [last_month.start_date, last_month.end_date]

    assert_equal "This year", this_year.label
    assert_equal [Date.new(2026, 1, 1), Date.new(2026, 6, 15)], [this_year.start_date, this_year.end_date]

    assert_equal "Last year", last_year.label
    assert_equal [Date.new(2025, 1, 1), Date.new(2025, 12, 31)], [last_year.start_date, last_year.end_date]
  end

  def test_from_preset_key_parses_last_n_pattern
    period = RecordingStudioAdmin::Period.from_preset_key(" last_24_hours ", reference_date: @reference_date)

    assert_equal 24, period.amount
    assert_equal :hour, period.unit
    assert_equal Date.new(2026, 5, 22), period.start_date
    assert_equal Date.new(2026, 6, 15), period.end_date
    assert_equal :last_24_hours, period.preset_key
  end

  def test_from_preset_key_returns_nil_for_blank_or_invalid_key
    assert_nil RecordingStudioAdmin::Period.from_preset_key("  ", reference_date: @reference_date)
    assert_nil RecordingStudioAdmin::Period.from_preset_key("current_week", reference_date: @reference_date)
  end

  def test_from_date_range_prefers_quick_preset_when_explicit_preset_is_provided
    period = RecordingStudioAdmin::Period.from_date_range(
      start_date: Date.new(2026, 6, 15),
      end_date: Date.new(2026, 6, 15),
      preset_key: :today,
      reference_date: @reference_date
    )

    assert_equal "Today", period.label
    assert_equal :today, period.preset_key
  end

  def test_from_date_range_infers_quick_presets
    period = RecordingStudioAdmin::Period.from_date_range(
      start_date: Date.new(2026, 6, 13),
      end_date: Date.new(2026, 6, 15),
      reference_date: @reference_date
    )

    assert_equal "Last 3 days", period.label
    assert_equal :last_3_days, period.preset_key
  end

  def test_from_date_range_uses_preset_pattern_when_not_quick
    period = RecordingStudioAdmin::Period.from_date_range(
      start_date: Date.new(2026, 5, 30),
      end_date: Date.new(2026, 6, 13),
      preset_key: :last_14_days,
      reference_date: @reference_date
    )

    assert_equal 14, period.amount
    assert_equal :day, period.unit
    assert_equal :last_14_days, period.preset_key
  end

  def test_from_date_range_uses_week_units_for_complete_week_spans_ending_today
    period = RecordingStudioAdmin::Period.from_date_range(
      start_date: Date.new(2026, 6, 2),
      end_date: Date.new(2026, 6, 15),
      reference_date: @reference_date
    )

    assert_equal 2, period.amount
    assert_equal :week, period.unit
    assert_equal "Last 2 weeks", period.label
  end

  def test_from_date_range_uses_day_units_for_non_week_spans_ending_today
    period = RecordingStudioAdmin::Period.from_date_range(
      start_date: Date.new(2026, 6, 11),
      end_date: Date.new(2026, 6, 15),
      reference_date: @reference_date
    )

    assert_equal 5, period.amount
    assert_equal :day, period.unit
    assert_equal "Last 5 days", period.label
  end

  def test_from_date_range_uses_explicit_range_label_when_not_ending_today
    period = RecordingStudioAdmin::Period.from_date_range(
      start_date: Date.new(2026, 6, 1),
      end_date: Date.new(2026, 6, 10),
      reference_date: @reference_date
    )

    assert_equal "Jun 1 to Jun 10", period.label
  end

  def test_from_date_range_returns_nil_without_dates
    assert_nil RecordingStudioAdmin::Period.from_date_range(
      start_date: nil,
      end_date: nil,
      reference_date: @reference_date
    )
  end
end
