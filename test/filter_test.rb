# frozen_string_literal: true

require "test_helper"

class FilterTest < Minitest::Test
  class RelationDouble
    attr_reader :clauses

    def initialize
      @clauses = []
    end

    def where(clause)
      @clauses << clause
      self
    end
  end

  def test_group_by_allows_only_known_values
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:group_by, :group_by, values: %i[hour day],
                                                                                               default: :day)

    assert_equal :hour, definition.normalize(group_by: "hour")
    assert_equal :day, definition.normalize(group_by: "quarter")
  end

  def test_date_range_ignores_invalid_dates
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:date_range, :date_range, {})
    value = definition.normalize(start_date: "bad", end_date: "2026-06-12")

    assert_nil value.start_date
    assert_equal Date.new(2026, 6, 12), value.end_date
  end

  def test_date_range_uses_last_30_days_default_when_no_params_are_supplied
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :date_range,
      :date_range,
      default: :last_30_days
    )

    with_singleton_stub(Date, :current, Date.new(2026, 6, 12)) do
      value = definition.normalize({})

      assert_equal Date.new(2026, 5, 13), value.start_date
      assert_equal Date.new(2026, 6, 12), value.end_date
      assert_equal :last_30_days, value.preset_key
    end
  end

  def test_date_range_applies_start_and_end_bounds_to_relation
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:created_at, :date_range, field: :occurred_at)
    value = definition.normalize(start_date: "2026-06-01", end_date: "2026-06-12")
    relation = RelationDouble.new

    definition.apply(relation, value, nil)

    assert_equal 2, relation.clauses.size
    assert_equal({ occurred_at: value.start_date.beginning_of_day.. }, relation.clauses.first)
    assert_equal({ occurred_at: ..value.end_date.end_of_day }, relation.clauses.last)
  end

  def test_select_filter_rejects_undeclared_options
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:status, :select, options: %w[open closed])

    assert_equal "open", definition.normalize(status: "open")
    assert_nil definition.normalize(status: "deleted")
  end

  def test_select_filter_apply_uses_custom_callback_and_default_where_fallback
    custom_relation = Object.new
    custom_result = [:scoped]
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      apply: ->(relation, value, context) { [relation, value, context, custom_result] }
    )

    assert_equal [custom_relation, "open", :ctx, custom_result], definition.apply(custom_relation, "open", :ctx)

    relation = RelationDouble.new
    default_definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:status, :select, field: :state)

    assert_same relation, default_definition.apply(relation, "closed", nil)
    assert_equal [{ state: "closed" }], relation.clauses
  end

  def test_select_filter_apply_returns_relation_unchanged_without_value_or_where_support
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:status, :select, {})
    relation = Object.new

    assert_same relation, definition.apply(relation, nil, nil)
    assert_same relation, definition.apply(relation, "open", nil)
  end
end
