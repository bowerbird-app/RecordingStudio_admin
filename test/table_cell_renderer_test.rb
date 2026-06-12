# frozen_string_literal: true

require "test_helper"

unless defined?(FlatPack::Timestamp::Component)
  module FlatPack
    module Timestamp
      class Component
        attr_reader :timestamp, :class_name

        def initialize(timestamp:, class_name:)
          @timestamp = timestamp
          @class_name = class_name
        end
      end
    end

    module Badge
      class Component
        attr_reader :text, :style, :size, :dot

        def initialize(text:, style:, size:, dot:)
          @text = text
          @style = style
          @size = size
          @dot = dot
        end
      end
    end
  end
end

class TableCellRendererTest < Minitest::Test
  class FakeColumn
    attr_reader :display

    def initialize(value:, display: nil, options: nil)
      @value = value
      @display = display
      @options = options
    end

    def cell(_row, _context)
      @value
    end

    def display_options_for(row, context, value)
      return unless @options

      @options.call(row, context, value)
    end
  end

  class FakeViewContext
    attr_reader :rendered_component, :localized_value

    def render(component)
      @rendered_component = component
    end

    def l(value)
      @localized_value = value
      "localized #{value.iso8601}"
    end
  end

  def test_renders_timestamp_component_for_time_values
    view_context = FakeViewContext.new

    result = RecordingStudioAdmin::TableCellRenderer.call(
      column: FakeColumn.new(value: Time.utc(2026, 6, 12, 10, 30)),
      row: Object.new,
      context: Object.new,
      view_context: view_context
    )

    assert_instance_of FlatPack::Timestamp::Component, result
    assert_same result, view_context.rendered_component
  end

  def test_renders_badge_component_with_defaults_when_options_missing
    view_context = FakeViewContext.new

    result = RecordingStudioAdmin::TableCellRenderer.call(
      column: FakeColumn.new(value: 500, display: :badge),
      row: Object.new,
      context: Object.new,
      view_context: view_context
    )

    assert_instance_of FlatPack::Badge::Component, result
    assert_same result, view_context.rendered_component
  end

  def test_localizes_plain_date_values
    date = Date.new(2026, 6, 12)
    view_context = FakeViewContext.new

    result = RecordingStudioAdmin::TableCellRenderer.call(
      column: FakeColumn.new(value: date),
      row: Object.new,
      context: Object.new,
      view_context: view_context
    )

    assert_equal "localized 2026-06-12", result
    assert_equal date, view_context.localized_value
  end

  def test_returns_plain_value_when_no_special_rendering_applies
    result = RecordingStudioAdmin::TableCellRenderer.call(
      column: FakeColumn.new(value: "plain text"),
      row: Object.new,
      context: Object.new,
      view_context: FakeViewContext.new
    )

    assert_equal "plain text", result
  end
end
