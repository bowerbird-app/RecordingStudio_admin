# frozen_string_literal: true

require "test_helper"

class QueryResultTest < Minitest::Test
  Relation = Struct.new(:count)

  def test_percent_change_with_previous_count
    result = RecordingStudioAdmin::Results::QueryResult.new(relation: Relation.new(345), previous_count: 257)

    assert_in_delta 34.2, result.change_percent, 0.1
    assert_equal :up, result.change_direction
  end

  def test_percent_change_zero_rules
    flat = RecordingStudioAdmin::Results::QueryResult.new(relation: Relation.new(0), previous_count: 0)
    new_growth = RecordingStudioAdmin::Results::QueryResult.new(relation: Relation.new(10), previous_count: 0)

    assert_equal 0, flat.change_percent
    assert_nil new_growth.change_percent
    assert_equal :up, new_growth.change_direction
  end
end
