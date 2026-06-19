# frozen_string_literal: true

module RecordingStudioAdmin
  class Screen < Definitions::Base
    class << self
      attr_reader :query_value, :filters_value, :chart_value, :table_value, :widgets_value, :summary_value,
                  :availability_scope_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@filters_value, [])
        subclass.instance_variable_set(:@widgets_value, {})
        subclass.instance_variable_set(:@summary_value, SummaryDefinition.new)
        subclass.instance_variable_set(:@availability_scope_value, nil)
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

      def widget(name, blast_radius: nil, &)
        definition = Widget.new(name, screen_key: key, blast_radius: blast_radius || self.blast_radius, &)
        @widgets_value[definition.key] = definition
      end

      def summary(**options, &block)
        @summary_value = SummaryDefinition.new(**options, &block) if options.any? || block
        @summary_value
      end

      def availability_scope(value = nil, &block)
        @availability_scope_value = block || normalize_availability_scope(value) if value || block
        @availability_scope_value || DEFAULT_SECTION_AVAILABILITY_SCOPE
      end

      def filters
        @filters_value || []
      end

      def widgets
        @widgets_value || {}
      end

      private

      def normalize_availability_scope(value)
        normalized = value.to_s.downcase.to_sym
        return normalized if SECTION_AVAILABILITY_SCOPES.include?(normalized)

        raise InvalidDefinition, "Screen availability_scope has unsupported value #{value.inspect}"
      end

      def builtin_filter_type(name)
        case name.to_sym
        when :date_range then :date_range
        when :group_by then :group_by
        else :select
        end
      end
    end
  end

  class SummaryDefinition
    attr_reader :show_metric_value, :show_change_value, :show_period_value

    def initialize(metric: true, change: true, period: true, &block)
      @show_metric_value = metric
      @show_change_value = change
      @show_period_value = period
      instance_eval(&block) if block
    end

    %i[label value previous_value change_good_when period_label].each do |name|
      define_method(name) do |value = nil, &block|
        instance_variable_set("@#{name}", block || value) if !value.nil? || block
        instance_variable_get("@#{name}")
      end
    end

    def hide_metric = @show_metric_value = false
    def hide_change = @show_change_value = false
    def hide_period = @show_period_value = false

    def show_metric(value = true) = @show_metric_value = value
    def show_change(value = true) = @show_change_value = value
    def show_period(value = true) = @show_period_value = value
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
    attr_reader :columns, :filters, :actions, :pagination_options, :default_sort_key, :default_direction,
                :export_key, :export_options

    def initialize(&block)
      @columns = []
      @filters = []
      @actions = []
      @default_column_keys = nil
      @export_key = nil
      @export_options = {}
      @pagination_options = { per_page: 50, mode: :infinite }
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

    def default_columns(*keys)
      @default_column_keys = keys.flatten.map(&:to_sym).uniq
    end

    def export(key = nil, **options)
      export_key = key || options.delete(:key)
      raise InvalidDefinition, "table export requires an export key" if export_key.blank?

      @export_key = export_key.to_s
      @export_options = options.symbolize_keys
    end

    def action(name, text:, url:, icon: nil, method: nil, confirm: nil, destructive: nil, visible_if: nil,
               blast_radius: nil)
      @actions << RowActionDefinition.new(
        name.to_sym,
        text,
        url,
        icon,
        method,
        confirm,
        destructive,
        visible_if,
        RecordingStudioAdmin::BlastRadius.normalize(blast_radius, owner: "Table action #{name.inspect}")
      )
    end

    def admin_action(resource_key, action_key = nil, as: nil)
      resource_key, action_key = resource_key.to_s.split(".", 2) if action_key.nil?
      if resource_key.blank? || action_key.blank?
        raise InvalidDefinition,
              "admin_action requires a resource key and action key"
      end

      @actions << ResourceRowActionDefinition.new(
        (as || "#{resource_key}_#{action_key}").to_sym,
        resource_key,
        action_key.to_sym
      )
    end

    def paginate(per_page: 50, mode: :infinite)
      @pagination_options = { per_page: per_page.to_i, mode: mode.to_sym }
    end

    def default_sort(key, direction: :desc)
      @default_sort_key = key&.to_sym
      @default_direction = direction.to_s == "asc" ? "asc" : "desc"
    end

    def default_column_keys
      return if @default_column_keys.nil?

      allowed_keys = columns.map(&:key)
      unknown_keys = @default_column_keys - allowed_keys
      return @default_column_keys if unknown_keys.empty?

      raise ArgumentError, "Unknown default columns: #{unknown_keys.join(', ')}"
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

  RowActionDefinition = Data.define(:name, :text, :url, :icon, :method, :confirm, :destructive, :visible_if,
                                    :blast_radius) do
    def resolve(row, context)
      return unless RecordingStudioAdmin::BlastRadius.allowed?(self, context: context)
      return if visible_if && !resolve_value(visible_if, row, context)

      resolved_url = RecordingStudioAdmin::UrlSafety.safe_href(resolve_value(url, row, context))
      return if resolved_url.blank?

      resolved_method = normalize_method(resolve_value(method, row, context))
      resolved_confirm = resolve_value(confirm, row, context)
      resolved_destructive = resolve_destructive(row, context, resolved_method)

      Results::ResolvedRowAction.new(
        name: name,
        text: resolve_value(text, row, context),
        url: resolved_url,
        icon: resolve_value(icon, row, context),
        method: resolved_method,
        confirm: resolved_confirm,
        destructive: resolved_destructive
      )
    end

    private

    def resolve_destructive(row, context, resolved_method)
      value = resolve_value(destructive, row, context)
      return value unless value.nil?

      resolved_method == :delete
    end

    def normalize_method(value)
      normalized = value.to_s.downcase.presence
      return if normalized.blank? || normalized == "get"

      normalized.to_sym
    end

    def resolve_value(value, row, context)
      return value unless value.respond_to?(:call)

      case value.arity
      when 0 then value.call
      when 1, -1 then value.call(row)
      else value.call(row, context)
      end
    end
  end

  ResourceRowActionDefinition = Data.define(:name, :resource_key, :action_key) do
    def blast_radius
      action_definition&.blast_radius || RecordingStudioAdmin::BlastRadius::DEFAULT
    end

    def authorize_for_table(context)
      action = RecordingStudioAdmin.resolve_table_resource_action(
        key: resource_key,
        action: action_key,
        context: context
      )

      AuthorizedResourceRowActionDefinition.new(name, action)
    rescue AuthorizationFailed, DefinitionNotFound
      nil
    end

    def resolve(row, context)
      action = RecordingStudioAdmin.authorize_resource!(
        key: resource_key,
        action: action_key,
        context: context,
        record: row
      )
      action.resolve(row, context)
    rescue AuthorizationFailed, DefinitionNotFound
      nil
    end

    private

    def action_definition
      RecordingStudioAdmin.resource_for(resource_key)&.action_for(action_key)
    end
  end

  AuthorizedResourceRowActionDefinition = Data.define(:name, :action_definition) do
    def blast_radius = action_definition.blast_radius

    def resolve(row, context)
      action_definition.resolve(row, context)
    end
  end
end
