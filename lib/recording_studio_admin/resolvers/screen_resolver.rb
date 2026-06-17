# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class ScreenResolver
      def self.call(key:, context:)
        new(key, context).call
      end

      def initialize(key, context)
        @key = key.to_s
        @context = context
      end

      def call
        definition = RecordingStudioAdmin.screen_for(@key)
        raise DefinitionNotFound, "Screen #{@key.inspect} is not registered" unless definition

        RecordingStudioAdmin::Authorization.authorize!(@context)
        raise DefinitionNotFound, "Screen #{@key.inspect} is not visible" unless visible?(definition)

        base_relation = definition.query.call(@context)
        relation = base_relation
        filters = resolve_filters(combined_filters(definition))
        filters.each { |filter| relation = filter[:definition].apply(relation, filter[:value], @context) }
        previous_count = previous_count_for(base_relation: base_relation, filters: filters)
        query_result = Results::QueryResult.new(relation: relation, previous_count: previous_count)
        @context.query_result = query_result

        table = resolve_table(definition.table_value, relation, filters: filters)
        summary = resolve_summary(
          definition.summary_value || SummaryDefinition.new,
          query_result: query_result,
          previous_count: previous_count
        )
        Results::ResolvedScreen.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          buttons: definition.buttons_value.filter_map { |button| button.resolve(@context) },
          filters: filters.map { |entry| resolved_filter(entry) },
          query_result: query_result,
          summary: summary,
          chart: resolve_chart(definition.chart_value),
          table: table,
          widgets: definition.widgets.values.map { |widget| widget.resolve(@context) }
        )
      end

      private

      def combined_filters(definition)
        (Array(definition.filters) + Array(definition.table_value&.filters)).uniq(&:param_key)
      end

      def resolve_filters(definitions)
        definitions.map do |definition|
          value = definition.normalize(@context.params)
          @context.set_filter_value(definition.key, value)
          { definition: definition, value: value }
        end
      end

      def resolved_filter(entry)
        definition = entry[:definition]
        Results::ResolvedFilter.new(
          definition.key,
          definition.type,
          entry[:value],
          definition.options.merge(values: definition.allowed_values),
          definition.param_key,
          definition.options.fetch(:start_param, :start_date).to_sym,
          definition.options.fetch(:end_param, :end_date).to_sym,
          definition.options.fetch(:preset_param, :date_range_preset).to_sym
        )
      end

      def resolve_chart(definition)
        return unless definition

        Results::ResolvedChart.new(
          evaluate(definition.title_value),
          evaluate(definition.subtitle_value),
          (evaluate(definition.type_value) || :line).to_sym,
          evaluate(definition.series_value) || [],
          evaluate(definition.options_value) || {}
        )
      end

      def resolve_table(definition, relation, filters: [])
        return unless definition

        table_filter_keys = Array(definition.filters).map(&:param_key)
        table_filters = filters.select { |entry| table_filter_keys.include?(entry[:definition].param_key) }
        visible_columns, selected_column_keys = resolve_visible_columns(definition)
        sorted_relation, sort, direction = sort_relation(definition, relation, columns: visible_columns)
        table_result = paginate(definition, sorted_relation, sort, direction)
        @context.table_result = table_result
        Results::ResolvedTable.new(visible_columns, table_filters.map do |entry|
          resolved_filter(entry)
        end, table_result.rows, definition.actions, table_result, definition.columns, selected_column_keys)
      end

      def resolve_summary(definition, query_result:, previous_count:)
        value = evaluate_summary(definition.value) || query_result.count
        previous_value = evaluate_summary(definition.previous_value)
        previous_value = previous_count if previous_value.nil?

        Results::ResolvedSummary.new(
          label: evaluate_summary(definition.label) || "Total",
          value: value,
          change: format_percent_change(percent_change(value, previous_value)),
          change_good_when: normalize_change_good_when(evaluate_summary(definition.change_good_when)),
          period_label: evaluate_summary(definition.period_label) || @context.period_label,
          show_metric: definition.show_metric_value,
          show_change: definition.show_change_value && !previous_value.nil?,
          show_period: definition.show_period_value
        )
      end

      def percent_change(current, previous)
        return if previous.nil?
        return 0 if previous.zero? && current.zero?
        return 100 if previous.zero? && current.positive?

        ((current - previous) / previous.to_f) * 100
      end

      def previous_count_for(base_relation:, filters:)
        previous_filters = filters.map { |entry| previous_filter_entry(entry) }
        return unless previous_filters.any? { |entry| date_range_filter?(entry[:definition]) && entry[:value] }

        previous_relation = base_relation
        previous_filters.each do |filter|
          previous_relation = filter[:definition].apply(previous_relation, filter[:value], @context)
        end
        relation_count(previous_relation)
      end

      def previous_filter_entry(entry)
        definition = entry[:definition]
        value = entry[:value]
        return entry unless date_range_filter?(definition)

        { definition: definition, value: previous_period_value(value) }
      end

      def date_range_filter?(definition)
        definition.type.to_sym == :date_range
      end

      def previous_period_value(value)
        return unless value.respond_to?(:start_date) && value.respond_to?(:end_date)
        return unless value.start_date && value.end_date

        span_days = (value.end_date - value.start_date).to_i + 1
        previous_end = value.start_date - 1.day
        previous_start = previous_end - (span_days - 1).days
        Filters::DateRangeFilter::RangeValue.new(previous_start, previous_end, nil)
      end

      def format_percent_change(value)
        return if value.nil?
        return "0%" if value.to_f.zero?

        format("%+.1f%%", value.to_f).sub(".0%", "%")
      end

      def normalize_change_good_when(value)
        normalized = (value || :up).to_s.downcase.to_sym
        normalized = :up if normalized == :positive
        normalized = :down if normalized == :negative
        normalized
      end

      def evaluate_summary(value)
        value.respond_to?(:call) ? value.call(@context) : value
      end

      def resolve_visible_columns(definition)
        allowed_columns = definition.columns
        allowed_keys = allowed_columns.map { |column| column.key.to_s }
        default_keys = Array(definition.default_column_keys).presence&.map(&:to_s) || allowed_keys
        requested_keys = requested_column_keys.select { |key| allowed_keys.include?(key) }
        selected_keys = if requested_keys.any?
                          requested_keys
                        elsif columns_param_present?
                          []
                        else
                          default_keys
                        end

        selected_keys = fallback_column_keys(default_keys, allowed_keys) if selected_keys.empty?

        [allowed_columns.select { |column| selected_keys.include?(column.key.to_s) }, selected_keys]
      end

      def requested_column_keys
        Array(@context.params[:columns] || @context.params["columns"]).filter_map do |value|
          value.to_s.presence
        end
      end

      def columns_param_present?
        @context.params.key?(:columns_present) || @context.params.key?("columns_present") ||
          @context.params.key?(:columns) || @context.params.key?("columns")
      end

      def fallback_column_keys(default_keys, allowed_keys)
        Array(default_keys).presence || Array(allowed_keys.first)
      end

      def sort_relation(definition, relation, columns: definition.columns)
        sortable = columns.select(&:sortable).map { |column| column.key.to_s }
        requested_sort = (@context.params[:sort] || @context.params["sort"] || definition.default_sort_key).to_s
        sort = sortable.include?(requested_sort) ? requested_sort : sortable.first
        direction = if %w[asc
                          desc].include?((@context.params[:direction] || @context.params["direction"]).to_s)
                      (@context.params[:direction] || @context.params["direction"]).to_s
                    else
                      definition.default_direction || "desc"
                    end
        return [relation, sort, direction] unless relation.respond_to?(:order) && sort

        [relation.order(sort => direction), sort, direction]
      end

      def paginate(definition, relation, sort, direction)
        per_page = definition.pagination_options.fetch(:per_page, 50)
        requested_page = [(@context.params[:page] || @context.params["page"] || 1).to_i, 1].max
        page = [requested_page, RecordingStudioAdmin.configuration.max_page].min
        total = relation_count(relation)
        rows = if relation.respond_to?(:limit)
                 relation.limit(per_page).offset((page - 1) * per_page).to_a
               else
                 Array(relation).slice((page - 1) * per_page, per_page) || []
               end
        Results::TableResult.new(rows, total, page, per_page, (total.to_f / per_page).ceil, sort, direction,
                                 definition.pagination_options[:mode])
      end

      def relation_count(relation)
        return Array(relation).size unless relation.respond_to?(:count)

        return grouped_relation_count(relation) if grouped_select_relation?(relation)

        normalized_count(relation.count)
      rescue StandardError => e
        raise unless active_record_statement_invalid?(e) && relation.respond_to?(:except)

        grouped_relation_count(relation)
      end

      def active_record_statement_invalid?(error)
        defined?(ActiveRecord::StatementInvalid) && error.is_a?(ActiveRecord::StatementInvalid)
      end

      def grouped_select_relation?(relation)
        relation.respond_to?(:group_values) && relation.respond_to?(:select_values) &&
          relation.group_values.any? && relation.select_values.any?
      end

      def grouped_relation_count(relation)
        normalized_count(relation.except(:select, :order).count)
      end

      def normalized_count(value)
        return value.size if value.is_a?(Hash)

        value
      end

      def evaluate(value)
        value.respond_to?(:call) ? value.call(@context) : value
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end
    end
  end
end
