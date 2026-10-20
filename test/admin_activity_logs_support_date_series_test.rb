# frozen_string_literal: true

require "test_helper"
require "active_support/time"
require "arel"

class AdminActivityLogsSupportDateSeriesTest < Minitest::Test
  class SeriesRelation
    def initialize(counts, where_ast: nil)
      @counts = counts
      @where_ast = where_ast
    end

    def except(*)
      self
    end

    def group(*)
      self
    end

    def order(*)
      self
    end

    def count
      @counts
    end

    def where_clause
      return unless @where_ast

      Struct.new(:ast).new(@where_ast)
    end
  end

  def setup
    @previous_zone = Time.zone
    Time.zone = "UTC"
  end

  def teardown
    Time.zone = @previous_zone
  end

  def test_fills_zero_day_buckets_across_an_inclusive_date_range
    start_at = Time.zone.local(2026, 6, 1).beginning_of_day
    end_at = Time.zone.local(2026, 6, 4).end_of_day
    counts = { Date.new(2026, 6, 1) => 2, Date.new(2026, 6, 4) => 5 }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :day)

    assert_equal [
      { x: "Jun 1", y: 2 },
      { x: "Jun 2", y: 0 },
      { x: "Jun 3", y: 0 },
      { x: "Jun 4", y: 5 }
    ], series
  end

  def test_fills_zero_week_buckets_across_an_inclusive_date_range
    start_at = Time.zone.local(2026, 6, 1).beginning_of_day
    end_at = Time.zone.local(2026, 6, 21).end_of_day
    first_week = Time.zone.local(2026, 6, 1).beginning_of_week
    third_week = Time.zone.local(2026, 6, 15).beginning_of_week
    counts = { first_week => 4, third_week => 1 }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:occurred_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(
      relation,
      field: :occurred_at,
      bucket: :week
    )

    assert_equal [
      { x: "Week of Jun 1", y: 4 },
      { x: "Week of Jun 8", y: 0 },
      { x: "Week of Jun 15", y: 1 }
    ], series
  end

  def test_fills_zero_month_buckets_across_an_inclusive_date_range
    start_at = Time.zone.local(2026, 1, 1).beginning_of_day
    end_at = Time.zone.local(2026, 4, 30).end_of_day
    counts = {
      Time.zone.local(2026, 1, 1).beginning_of_month => 9,
      Time.zone.local(2026, 4, 1).beginning_of_month => 3
    }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :month)

    assert_equal [
      { x: "Jan", y: 9 },
      { x: "Feb", y: 0 },
      { x: "Mar", y: 0 },
      { x: "Apr", y: 3 }
    ], series
  end

  def test_range_edges_are_inclusive_for_the_start_and_end_days
    start_at = Time.zone.local(2026, 6, 8).beginning_of_day
    end_at = Time.zone.local(2026, 6, 10).end_of_day
    counts = { Date.new(2026, 6, 8) => 1, Date.new(2026, 6, 10) => 1 }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation)

    assert_equal "Jun 8", series.first[:x]
    assert_equal "Jun 10", series.last[:x]
    assert_equal 3, series.length
    assert_equal 0, series[1][:y]
  end

  def test_keeps_the_same_points_when_every_bucket_has_data
    start_at = Time.zone.local(2026, 6, 1).beginning_of_day
    end_at = Time.zone.local(2026, 6, 3).end_of_day
    counts = {
      Date.new(2026, 6, 1) => 2,
      Date.new(2026, 6, 2) => 4,
      Date.new(2026, 6, 3) => 1
    }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :day)

    assert_equal [
      { x: "Jun 1", y: 2 },
      { x: "Jun 2", y: 4 },
      { x: "Jun 3", y: 1 }
    ], series
  end

  def test_fills_gaps_between_first_and_last_bucket_when_no_filter_range_is_present
    counts = { Date.new(2026, 6, 1) => 2, Date.new(2026, 6, 4) => 5 }
    relation = SeriesRelation.new(counts)

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :day)

    assert_equal [
      { x: "Jun 1", y: 2 },
      { x: "Jun 2", y: 0 },
      { x: "Jun 3", y: 0 },
      { x: "Jun 4", y: 5 }
    ], series
  end

  def test_returns_an_empty_series_when_there_is_no_range_and_no_counts
    relation = SeriesRelation.new({})

    assert_empty RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation)
  end

  def test_does_not_expand_hour_buckets_past_the_series_cap
    start_at = Time.zone.local(2025, 1, 1).beginning_of_day
    end_at = Time.zone.local(2025, 12, 31).end_of_day
    counted_at = Time.zone.local(2025, 6, 15, 10)
    counts = { counted_at => 7 }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :hour)

    assert_equal [{ x: "10am", y: 7 }], series
  end

  def test_reads_a_single_inclusive_between_range
    start_at = Time.zone.local(2026, 6, 1).beginning_of_day
    end_at = Time.zone.local(2026, 6, 3).end_of_day
    table = Arel::Table.new(:items)
    ast = Arel::Nodes::Between.new(table[:created_at], start_at..end_at)
    relation = SeriesRelation.new({ Date.new(2026, 6, 1) => 1 }, where_ast: ast)

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :day)

    assert_equal [
      { x: "Jun 1", y: 1 },
      { x: "Jun 2", y: 0 },
      { x: "Jun 3", y: 0 }
    ], series
  end

  def test_matches_qualified_field_names_to_the_filtered_column
    start_at = Time.zone.local(2026, 6, 1).beginning_of_day
    end_at = Time.zone.local(2026, 6, 2).end_of_day
    counts = { Date.new(2026, 6, 1) => 3 }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(
      relation,
      field: "recording_studio_ai_runs.created_at",
      bucket: :day
    )

    assert_equal [
      { x: "Jun 1", y: 3 },
      { x: "Jun 2", y: 0 }
    ], series
  end

  def test_uses_the_host_time_zone_for_day_labels
    Time.zone = "Pacific Time (US & Canada)"
    start_at = Time.zone.local(2026, 6, 1).beginning_of_day
    end_at = Time.zone.local(2026, 6, 2).end_of_day
    counts = { start_at => 1 }
    relation = SeriesRelation.new(counts, where_ast: range_ast(:created_at, start_at, end_at))

    series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :day)

    assert_equal [
      { x: "Jun 1", y: 1 },
      { x: "Jun 2", y: 0 }
    ], series
  end

  private

  def range_ast(field, start_at, end_at)
    table = Arel::Table.new(:items)
    Arel::Nodes::And.new([
                           Arel::Nodes::GreaterThanOrEqual.new(table[field], start_at),
                           Arel::Nodes::LessThanOrEqual.new(table[field], end_at)
                         ])
  end
end
