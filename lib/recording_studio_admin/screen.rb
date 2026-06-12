# frozen_string_literal: true

module RecordingStudioAdmin
  class Screen < Definitions::Base
    class << self
      attr_reader :query_value, :filters_value, :chart_value, :table_value, :widgets_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@filters_value, [])
        subclass.instance_variable_set(:@widgets_value, {})
      end

      def query(&block)
        @query_value = block if block
        @query_value
      end

      def filter(name, **options)
        type = builtin_filter_type(name)
        @filters_value << Definitions::FilterDefinition.new(name.to_sym, type, options)
      end

      def chart(&block)
        @chart_value = ChartDefinition.new(&block) if block
        @chart_value
      end

      def table(&block)
        @table_value = TableDefinition.new(&block) if block
        @table_value
      end

      def widget(name, &)
        definition = Widget.new(name, screen_key: key, &)
        @widgets_value[definition.key] = definition
      end

      def filters
        @filters_value || []
      end

      def widgets
        @widgets_value || {}
      end

      private

      def builtin_filter_type(name)
        case name.to_sym
        when :date_range then :date_range
        when :group_by then :group_by
        else :select
        end
      end
    end
  end

  class ChartDefinition
    attr_reader :title_value, :subtitle_value, :type_value, :series_value, :options_value

    def initialize(&block)
      instance_eval(&block) if block
    end

    %i[title subtitle type series options].each do |name|
      define_method(name) do |value = nil, &block|
        instance_variable_set("@#{name}_value", block || value) if value || block
        instance_variable_get("@#{name}_value")
      end
    end
  end

  class TableDefinition
    attr_reader :columns, :filters, :actions, :pagination_options, :default_sort_key, :default_direction

    def initialize(&block)
      @columns = []
      @filters = []
      @actions = []
      @pagination_options = { per_page: 50, mode: :standard }
      instance_eval(&block) if block
    end

    def filter(name, **options)
      @filters << Definitions::FilterDefinition.new(name.to_sym, :select, options)
    end

    def column(name, title: nil, sortable: true, tooltip: nil, header_tooltip: nil, value: nil, display: nil,
               display_options: nil)
      @columns << ColumnDefinition.new(name.to_sym, title || name.to_s.humanize, sortable, tooltip, header_tooltip,
                                       value, display, display_options)
    end

    def action(name, text:, url:, visible_if: nil)
      @actions << RowActionDefinition.new(name.to_sym, text, url, visible_if)
    end

    def paginate(per_page: 50, mode: :standard)
      @pagination_options = { per_page: per_page.to_i, mode: mode.to_sym }
    end

    def default_sort(key, direction: :desc)
      @default_sort_key = key&.to_sym
      @default_direction = direction.to_s == "asc" ? "asc" : "desc"
    end
  end

  ColumnDefinition = Data.define(:key, :title, :sortable, :tooltip, :header_tooltip, :value, :display,
                                 :display_options) do
    def cell(row, context)
      value.respond_to?(:call) ? value.call(row, context) : row.public_send(key)
    end

    def tooltip_for(row, context)
      tooltip.respond_to?(:call) ? tooltip.call(row, context) : tooltip
    end

    def display_options_for(row, context, cell_value)
      return {} unless display_options
      return display_options unless display_options.respond_to?(:call)

      case display_options.arity
      when 0 then display_options.call
      when 1 then display_options.call(row)
      when 2 then display_options.call(row, context)
      else display_options.call(row, context, cell_value)
      end
    end
  end

  RowActionDefinition = Data.define(:name, :text, :url, :visible_if) do
    def resolve(row, context)
      return if visible_if && !visible_if.call(row, context)

      Results::ResolvedRowAction.new(name: name, text: text,
                                     url: RecordingStudioAdmin::UrlSafety.safe_href(url.call(row, context)))
    end
  end
end
