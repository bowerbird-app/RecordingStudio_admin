# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class ScreenResolver
      def self.call(key:, context:, resolve_widgets: true, resolve_summary: true, resolve_chart: true,
                    resolve_table: true, resolve_table_rows: true, resolve_table_count: true)
        new(
          key,
          context,
          resolve_widgets: resolve_widgets,
          resolve_summary: resolve_summary,
          resolve_chart: resolve_chart,
          resolve_table: resolve_table,
          resolve_table_rows: resolve_table_rows,
          resolve_table_count: resolve_table_count
        ).call
      end

      def self.resolve_widget(key:, widget_key:, context:, view_variant: nil)
        new(key, context).resolve_widget(widget_key, view_variant: view_variant)
      end

      def initialize(key, context, resolve_widgets: true, resolve_summary: true, resolve_chart: true,
                     resolve_table: true, resolve_table_rows: true, resolve_table_count: true)
        @key = key.to_s
        @context = context
        @resolve_widgets = resolve_widgets
        @resolve_summary = resolve_summary
        @resolve_chart = resolve_chart
        @resolve_table = resolve_table
        @resolve_table_rows = resolve_table_rows
        @resolve_table_count = resolve_table_count
      end

      def call
        definition = authorized_definition
        query_state = build_query_state(definition, resolve_query_count: @resolve_summary)
        filters = query_state.fetch(:filters)
        relation = query_state.fetch(:relation)
        query_result = query_state.fetch(:query_result)

        table = if @resolve_table
                  resolve_table(
                    definition.table_value,
                    relation,
                    owner: definition,
                    filters: filters,
                    with_rows: @resolve_table_rows,
                    with_count: @resolve_table_count
                  )
                end
        summary = if @resolve_summary
                    resolve_summary(
                      definition.summary_value || SummaryDefinition.new,
                      query_result: query_result,
                      previous_count: query_result.previous_count
                    )
                  end
        Results::ResolvedScreen.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          buttons: definition.buttons_value.filter_map { |button| button.resolve(@context) },
          filters: filters.map { |entry| resolved_filter(entry) },
          query_result: query_result,
          summary: summary,
          chart: (@resolve_chart ? resolve_chart(definition.chart_value) : nil),
          table: table,
          widgets: resolve_screen_widgets(definition),
          has_chart: definition.chart_value.present?,
          has_table: definition.table_value.present?
        )
      end

      def resolve_widget(widget_key, view_variant: nil)
        definition = authorized_definition
        build_query_state(definition, resolve_query_count: true)
        widget = definition.widgets.values.find { |candidate| candidate.key == widget_key.to_s }
        unless widget
          raise DefinitionNotFound,
                "Widget #{widget_key.inspect} is not registered for screen #{@key.inspect}"
        end

        resolved_widget = resolve_screen_widget(definition, widget)
        raise DefinitionNotFound, "Widget #{widget_key.inspect} is not available" unless resolved_widget

        apply_view_variant(resolved_widget, view_variant)
      end

      private

      def authorized_definition
        definition = RecordingStudioAdmin.screen_for(@key)
        raise DefinitionNotFound, "Screen #{@key.inspect} is not registered" unless definition

        RecordingStudioAdmin::Authorization.authorize!(@context)
        RecordingStudioAdmin::BlastRadius.authorize!(definition, context: @context,
                                                                 label: "Screen #{definition.key.inspect}")
        raise DefinitionNotFound, "Screen #{@key.inspect} is not enabled for this root" unless enabled?(definition)
        raise DefinitionNotFound, "Screen #{@key.inspect} is not visible" unless visible?(definition)

        definition
      end

      def build_query_state(definition, resolve_query_count: true)
        base_relation = definition.query.call(@context)
        relation = base_relation
        filters = resolve_filters(combined_filters(definition))
        filters.each { |filter| relation = filter[:definition].apply(relation, filter[:value], @context) }
        previous_count = previous_count_for(base_relation: base_relation, filters: filters) if resolve_query_count
        query_result = Results::QueryResult.new(
          relation: relation,
          previous_count: previous_count,
          resolve_count: resolve_query_count
        )
        @context.query_result = query_result

        { filters: filters, relation: relation, query_result: query_result }
      end

      def enabled?(definition)
        RecordingStudioAdmin.screen_enabled?(
          key: definition.key,
          recording: @context.access_recording,
          context: @context
        )
      end

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

      def resolve_table(definition, relation, owner:, filters: [], with_rows: true, with_count: true)
        return unless definition

        table_filter_keys = Array(definition.filters).map(&:param_key)
        table_filters = filters.select { |entry| table_filter_keys.include?(entry[:definition].param_key) }
        visible_columns, selected_column_keys = resolve_visible_columns(definition)
        sorted_relation, sort, direction = sort_relation(definition, relation, columns: visible_columns)
        table_result = paginate(
          definition,
          sorted_relation,
          sort,
          direction,
          with_rows: with_rows,
          with_count: with_count
        )
        @context.table_result = table_result
        actions = definition.actions.filter_map do |action|
          if action.respond_to?(:authorize_for_table)
            action.authorize_for_table(@context)
          elsif RecordingStudioAdmin::BlastRadius.allowed?(action, context: @context, container: owner)
            action
          end
        end

        Results::ResolvedTable.new(visible_columns, table_filters.map do |entry|
          resolved_filter(entry)
        end, table_result.rows, actions, table_result, definition.columns, selected_column_keys,
                                   definition.export_key, definition.export_options)
      end

      def resolve_screen_widget(screen_definition, widget)
        return unless RecordingStudioAdmin::BlastRadius.allowed?(widget, context: @context,
                                                                         container: screen_definition)

        widget.resolve(@context)
      end

      def resolve_screen_widgets(definition)
        definition.widgets.values.filter_map do |widget|
          if @resolve_widgets
            resolve_screen_widget(definition, widget)
          else
            placeholder_widget(definition, widget)
          end
        end
      end

      def placeholder_widget(screen_definition, widget)
        return unless RecordingStudioAdmin::BlastRadius.allowed?(widget, context: @context,
                                                                         container: screen_definition)

        Results::ResolvedWidget.new(
          key: widget.key,
          type: widget.send(:evaluate, widget.type, @context).to_s.downcase.to_sym,
          title: widget.send(:evaluate, widget.title, @context),
          subtitle: widget.send(:evaluate, widget.subtitle, @context),
          description: widget.send(:evaluate, widget.description, @context),
          value: nil,
          change: nil,
          change_good_when: :neutral,
          link_to: nil,
          link_label: widget.send(:evaluate, widget.link_label, @context),
          series: nil,
          chart_type: widget.send(:evaluate, widget.chart_type, @context),
          chart_options: {},
          list_options: {},
          items: nil,
          rows: nil,
          metadata: {},
          view_variant: nil,
          show_metric: false,
          show_change: false,
          show_period: false
        )
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

      def apply_view_variant(widget, view_variant)
        normalized_variant = normalize_widget_view_variant(view_variant)
        return widget if normalized_variant.nil?

        widget.with(view_variant: normalized_variant)
      end

      def normalize_widget_view_variant(value)
        return nil if value.blank? || value.to_s == "__default__"

        RecordingStudioAdmin::Section.normalize_view_variant(value)
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

      def paginate(definition, relation, sort, direction, with_rows: true, with_count: true)
        per_page = definition.pagination_options.fetch(:per_page, 50)
        requested_page = [(@context.params[:page] || @context.params["page"] || 1).to_i, 1].max
        page = [requested_page, RecordingStudioAdmin.configuration.max_page].min
        total = relation_count(relation) if with_count
        rows = if with_rows
                 if relation.respond_to?(:limit)
                   relation.limit(limit_for(per_page, with_count: with_count)).offset((page - 1) * per_page).to_a
                 else
                   Array(relation).slice((page - 1) * per_page, limit_for(per_page, with_count: with_count)) || []
                 end
               else
                 []
               end
        total_pages = (total.to_f / per_page).ceil if total
        has_more = if with_count
                     page < total_pages
                   else
                     rows.length > per_page
                   end
        rows = rows.first(per_page) unless with_count
        Results::TableResult.new(rows, total, page, per_page, total_pages, sort, direction,
                                 definition.pagination_options[:mode], has_more, !with_count)
      end

      def limit_for(per_page, with_count:)
        with_count ? per_page : per_page + 1
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
