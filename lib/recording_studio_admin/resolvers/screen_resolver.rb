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
        raise DefinitionNotFound, "Screen #{@key.inspect} is not visible" unless visible?(definition)

        relation = definition.query.call(@context)
        filters = resolve_filters(definition.filters)
        filters.each { |filter| relation = filter[:definition].apply(relation, filter[:value], @context) }
        query_result = Results::QueryResult.new(relation: relation)
        @context.query_result = query_result

        table = resolve_table(definition.table_value, relation)
        Results::ResolvedScreen.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          buttons: definition.buttons_value.filter_map { |button| button.resolve(@context) },
          filters: filters.map { |entry| resolved_filter(entry) },
          query_result: query_result,
          chart: resolve_chart(definition.chart_value),
          table: table,
          widgets: definition.widgets.values.map { |widget| widget.resolve(@context) }
        )
      end

      private

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
          definition.options,
          definition.param_key,
          definition.options.fetch(:start_param, :start_date).to_sym,
          definition.options.fetch(:end_param, :end_date).to_sym
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

      def resolve_table(definition, relation)
        return unless definition

        table_relation = relation
        table_filters = resolve_filters(definition.filters)
        table_filters.each do |filter|
          table_relation = filter[:definition].apply(table_relation, filter[:value], @context)
        end
        sorted_relation, sort, direction = sort_relation(definition, table_relation)
        table_result = paginate(definition, sorted_relation, sort, direction)
        @context.table_result = table_result
        Results::ResolvedTable.new(definition.columns, table_filters.map do |entry|
          resolved_filter(entry)
        end, table_result.rows, definition.actions, table_result)
      end

      def sort_relation(definition, relation)
        sortable = definition.columns.select(&:sortable).map { |column| column.key.to_s }
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
        total = relation.respond_to?(:count) ? relation.count : Array(relation).size
        rows = if relation.respond_to?(:limit)
                 relation.limit(per_page).offset((page - 1) * per_page).to_a
               else
                 Array(relation).slice((page - 1) * per_page, per_page) || []
               end
        Results::TableResult.new(rows, total, page, per_page, (total.to_f / per_page).ceil, sort, direction,
                                 definition.pagination_options[:mode])
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
