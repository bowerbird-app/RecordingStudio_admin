# frozen_string_literal: true

module RecordingStudioAdmin
  class TableCellRenderer
    def self.call(column:, row:, context:, view_context:)
      new(column: column, row: row, context: context, view_context: view_context).call
    end

    def initialize(column:, row:, context:, view_context:)
      @column = column
      @row = row
      @context = context
      @view_context = view_context
    end

    def call
      value = @column.cell(@row, @context)

      case display_for(value)
      when :timestamp
        @view_context.render FlatPack::Timestamp::Component.new(timestamp: value, class_name: "text-sm")
      when :badge
        render_badge(value)
      else
        format_plain_value(value)
      end
    end

    private

    def display_for(value)
      return @column.display.to_sym if @column.display
      return :timestamp if value.is_a?(Time) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)

      :text
    end

    def render_badge(value)
      options = (@column.display_options_for(@row, @context, value) || {}).to_h.symbolize_keys

      @view_context.render FlatPack::Badge::Component.new(
        text: options[:text] || value.to_s,
        style: options[:style] || :default,
        size: options[:size] || :sm,
        dot: options[:dot] || false
      )
    end

    def format_plain_value(value)
      return @view_context.l(value) if value.is_a?(Date)

      value
    end
  end
end
