# frozen_string_literal: true

require "test_helper"
require "active_record"

class FiltersIlikeTest < Minitest::Test
  class RelationDouble
    attr_reader :calls

    def initialize
      @calls = []
    end

    def where(*args)
      @calls << args
      self
    end
  end

  def test_pattern_escapes_percent_and_underscore
    assert_equal "%100\\%\\_done\\_%", RecordingStudioAdmin::Filters::Ilike.pattern("100%_done_")
  end

  def test_pattern_wraps_plain_text
    assert_equal "%hello%", RecordingStudioAdmin::Filters::Ilike.pattern("hello")
  end

  def test_pattern_strip_removes_leading_and_trailing_spaces
    assert_equal "%hello%", RecordingStudioAdmin::Filters::Ilike.pattern("  hello  ", strip: true)
    assert_equal "%  hello  %", RecordingStudioAdmin::Filters::Ilike.pattern("  hello  ")
  end

  def test_apply_returns_relation_unchanged_for_blank_input
    relation = RelationDouble.new

    assert_same relation, RecordingStudioAdmin::Filters::Ilike.apply(relation, nil, columns: [:path])
    assert_same relation, RecordingStudioAdmin::Filters::Ilike.apply(relation, "", columns: [:path])
    assert_same relation, RecordingStudioAdmin::Filters::Ilike.apply(relation, "   ", columns: [:path])
    assert_empty relation.calls
  end

  def test_apply_builds_or_clause_across_multiple_columns
    relation = RelationDouble.new

    result = RecordingStudioAdmin::Filters::Ilike.apply(
      relation,
      "Acme",
      columns: %i[resource_key action_key outcome]
    )

    assert_same relation, result
    assert_equal 1, relation.calls.size
    sql, binds = relation.calls.first
    assert_equal "resource_key ILIKE :q OR action_key ILIKE :q OR outcome ILIKE :q", sql
    assert_equal({ q: "%Acme%" }, binds)
  end

  def test_apply_escapes_percent_and_underscore_in_bind
    relation = RelationDouble.new

    RecordingStudioAdmin::Filters::Ilike.apply(
      relation,
      "a%b_c",
      columns: [:path]
    )

    _sql, binds = relation.calls.first
    assert_equal({ q: "%a\\%b\\_c%" }, binds)
  end

  def test_apply_accepts_qualified_columns_and_expressions
    relation = RelationDouble.new

    RecordingStudioAdmin::Filters::Ilike.apply(
      relation,
      "12",
      columns: [
        "recording_studio_webhooks_endpoints.label",
        "CAST(id AS TEXT)"
      ]
    )

    sql, = relation.calls.first
    assert_equal(
      "recording_studio_webhooks_endpoints.label ILIKE :q OR CAST(id AS TEXT) ILIKE :q",
      sql
    )
  end

  def test_admin_activity_logs_screen_uses_ilike_helper
    filter = RecordingStudioAdmin::AdminActivityLogsScreen.table_value.filters.find { |item| item.key == :search }
    assert filter, "admin activity logs table should declare a search filter"

    relation = RelationDouble.new
    filter.options[:apply].call(relation, "users.create", nil)

    sql, binds = relation.calls.first
    assert_equal(
      [
        "resource_key ILIKE :q OR action_key ILIKE :q OR outcome ILIKE :q OR ",
        "actor_type ILIKE :q OR record_type ILIKE :q OR request_id ILIKE :q"
      ].join,
      sql
    )
    assert_equal({ q: "%users.create%" }, binds)

    filter.options[:apply].call(relation, "100%_done", nil)
    _sql, escaped_binds = relation.calls.last
    assert_equal({ q: "%100\\%\\_done%" }, escaped_binds)
  end

  def test_on_callable_skips_blank_and_filters_when_present
    apply = RecordingStudioAdmin::Filters::Ilike.on(:email)
    relation = RelationDouble.new

    assert_same relation, apply.call(relation, "", nil)
    assert_empty relation.calls

    apply.call(relation, "a_b%", nil)
    _sql, binds = relation.calls.first
    assert_equal({ q: "%a\\_b\\%%" }, binds)
  end

  def test_apply_requires_at_least_one_column
    error = assert_raises(ArgumentError) do
      RecordingStudioAdmin::Filters::Ilike.apply(RelationDouble.new, "x", columns: [])
    end
    assert_match(/at least one column/i, error.message)
  end
end
