# frozen_string_literal: true

require "test_helper"

unless defined?(ActiveRecord::StatementInvalid)
  module ActiveRecord
    class StatementInvalid < StandardError; end
  end
end

class QueryResultTest < Minitest::Test
  class Relation
    attr_reader :count

    def initialize(count)
      @count = count
    end
  end

  class GroupedSelectRelation
    def group_values = [:error_class]
    def select_values = ["error_class, COUNT(*) AS error_count"]

    def count
      raise ActiveRecord::StatementInvalid, "invalid grouped select count"
    end

    def except(*_keys)
      GroupedCountRelation.new
    end
  end

  class GroupedCountRelation
    def count
      { "TimeoutError" => 2, "ValidationError" => 1 }
    end
  end

  def test_percent_change_with_previous_count
    result = RecordingStudioAdmin::Results::QueryResult.new(relation: Relation.new(345), previous_count: 257)

    assert_in_delta 34.2, result.change_percent, 0.1
    assert_equal :up, result.change_direction
  end

  def test_percent_change_zero_rules
    flat = RecordingStudioAdmin::Results::QueryResult.new(relation: Relation.new(0), previous_count: 0)
    new_growth = RecordingStudioAdmin::Results::QueryResult.new(relation: Relation.new(10), previous_count: 0)

    assert_equal 0, flat.change_percent
    assert_equal 100, new_growth.change_percent
    assert_equal :up, new_growth.change_direction
  end

  def test_grouped_select_relations_fall_back_to_group_count
    result = RecordingStudioAdmin::Results::QueryResult.new(relation: GroupedSelectRelation.new)

    assert_equal 2, result.count
  end
end
