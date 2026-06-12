# frozen_string_literal: true

require "test_helper"

class FilterTest < Minitest::Test
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

  def test_select_filter_rejects_undeclared_options
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(:status, :select, options: %w[open closed])

    assert_equal "open", definition.normalize(status: "open")
    assert_nil definition.normalize(status: "deleted")
  end
end
