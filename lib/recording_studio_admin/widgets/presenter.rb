# frozen_string_literal: true

module RecordingStudioAdmin
  module Widgets
    class Presenter
      SUPPORTED_CHART_TYPES = %i[line column bar area donut pie radar gauge geochart].freeze
      FULL_CARD_HEIGHT_CLASS = "h-[26rem]"
      FULL_CHART_HEIGHT = 200
      FULL_LIST_LIMIT = 5
      X_TICK_AMOUNT = 6
      Y_TICK_AMOUNT = 5
      CATEGORY_REPEAT_MARK = "\u200b"
      CHART_TYPE_ALIASES = {
        geo: :geochart
      }.freeze
      INTEGER_TICK_CHART_TYPES = %i[line column bar stacked_column stacked_bar area radar].freeze

      def self.renderable_chart_type(type, default: :line)
        normalized = (type || default).to_s.downcase.to_sym
        normalized = CHART_TYPE_ALIASES.fetch(normalized, normalized)
        return normalized if SUPPORTED_CHART_TYPES.include?(normalized)

        :bar
      end

      def self.integer_ticks?(type, series: nil, default: :line, chart_options: nil)
        options = chart_options || {}
        return false if options[:integer_ticks] == false || options["integer_ticks"] == false
        return false unless INTEGER_TICK_CHART_TYPES.include?(renderable_chart_type(type, default: default))

        integer_y_values?(series)
      end

      def self.marker_options_for_sparse_line(type, series)
        chart_type = renderable_chart_type(type, default: :line)
        return {} unless %i[line area].include?(chart_type)
        return {} unless sparse_line_series?(series)

        { markers: { size: 5 } }
      end

      def self.plot_series(series)
        case series
        when Hash
          plot_series_entry(series)
        when Array
          series.map { |entry| entry.is_a?(Hash) ? plot_series_entry(entry) : entry }
        else
          series
        end
      end

      def self.readable_axis_options(type, series, compact: false)
        return {} if compact
        return {} unless category_chart?(type, series)

        options = {
          xaxis: {
            type: "category",
            tickAmount: X_TICK_AMOUNT,
            labels: {
              hideOverlappingLabels: true,
              rotate: 0
            }
          }
        }
        return options unless integer_ticks?(type, series: series)

        options.merge(yaxis: count_yaxis(series))
      end

      def self.plot_series_entry(entry)
        data_key = if entry.key?(:data)
                     :data
                   elsif entry.key?("data")
                     "data"
                   end
        return entry unless data_key

        points = entry[data_key]
        return entry unless points.is_a?(Array)

        entry.merge(data_key => distinct_category_points(points))
      end
      private_class_method :plot_series_entry

      def self.distinct_category_points(points)
        seen = Hash.new(0)

        points.map do |point|
          key = category_key(point)
          label = key && point[key]
          next point unless label.is_a?(String)

          occurrence = seen[label]
          seen[label] += 1
          next point if occurrence.zero?

          point.merge(key => "#{label}#{CATEGORY_REPEAT_MARK * occurrence}")
        end
      end
      private_class_method :distinct_category_points

      def self.category_key(point)
        return unless point.is_a?(Hash)
        return :x if point.key?(:x)
        return "x" if point.key?("x")

        nil
      end
      private_class_method :category_key

      def self.category_chart?(type, series)
        return false unless %i[line column bar area].include?(renderable_chart_type(type, default: :line))

        series_entries(series).any? { |entry| string_category_entry?(entry) }
      end
      private_class_method :category_chart?

      def self.string_category_entry?(entry)
        return false unless entry.is_a?(Hash)

        Array(entry[:data] || entry["data"]).any? { |point| string_category_point?(point) }
      end
      private_class_method :string_category_entry?

      def self.string_category_point?(point)
        point.is_a?(Hash) && (point[:x] || point["x"]).is_a?(String)
      end
      private_class_method :string_category_point?

      def self.count_yaxis(series)
        peak = plotted_y_values(series).grep(Integer).max || 0
        peak = 0 if peak.negative?
        step = [(peak / 4.0).ceil, 1].max

        {
          min: 0,
          max: step * Y_TICK_AMOUNT,
          tickAmount: Y_TICK_AMOUNT,
          stepSize: step,
          decimalsInFloat: 0
        }
      end
      private_class_method :count_yaxis

      def self.sparse_line_series?(series)
        entries = Array(series)
        return false if entries.empty?

        entries.all? do |entry|
          points = entry.is_a?(Hash) ? Array(entry[:data] || entry["data"]) : Array(entry)
          points.size < 2
        end
      end
      private_class_method :sparse_line_series?

      def self.integer_y_values?(series)
        return false if series.nil?

        plotted_y_values(series).all?(Integer)
      end
      private_class_method :integer_y_values?

      def self.plotted_y_values(series)
        series_entries(series).flat_map { |entry| series_entry_y_values(entry) }
      end
      private_class_method :plotted_y_values

      def self.series_entries(series)
        case series
        when nil
          []
        when Hash
          [series]
        else
          Array(series)
        end
      end
      private_class_method :series_entries

      def self.series_entry_y_values(entry)
        points = if entry.is_a?(Hash)
                   entry[:data] || entry["data"] || entry[:y] || entry["y"]
                 else
                   entry
                 end

        Array(points).flat_map { |point| point_y_value(point) }
      end
      private_class_method :series_entry_y_values

      def self.point_y_value(point)
        case point
        when Hash
          [point[:y] || point["y"]]
        when Array
          [point.last]
        else
          [point]
        end
      end
      private_class_method :point_y_value

      def initialize(widget, link_policy: nil)
        @widget = widget
        @link_policy = link_policy
      end

      def compact?
        widget.view_variant == :compact
      end

      def href
        return unless widget.link_to.present?

        if link_policy
          link_policy.call(widget.link_to)
        else
          RecordingStudioAdmin::UrlSafety.safe_href(widget.link_to)
        end
      end

      def compact_href
        href if compact?
      end

      def link_label
        widget.link_label.presence || "Admin screen"
      end

      def compact_tooltip_text
        "Open #{link_label}" if compact_href.present?
      end

      def header_subtitle
        widget.subtitle.presence
      end

      def period_label
        metadata_value(:period_label) if widget.show_period
      end

      def compact_period_label
        return compact_list_period_label if widget.type == :list

        period_label unless widget.type == :progress
      end

      def compact_metric_value
        return unless widget.show_metric

        value = metric_value
        compact_number(value) || value
      end

      def compact_metric_tooltip_text
        value = metric_value
        return unless value.is_a?(Numeric)
        return unless compact_number(value)

        exact_number(value)
      end

      def compact_unit_label
        unit_label if unit_label.present?
      end

      def compact_list_preview_mode
        preview_mode = widget.list_options&.[](:compact_preview).presence || :text_summary
        preview_mode.to_s.downcase.to_sym
      end

      def compact_list_visual_stack?
        compact_list_preview_mode == :visual_stack
      end

      def compact_list_text_summary(limit: 2)
        text_items = list_items.first(limit).map { |item| list_item_text(item) }.compact_blank
        return if text_items.empty?

        remainder = [list_count - text_items.size, 0].max
        summary = text_items.join(", ")
        remainder.positive? ? "#{summary} +#{remainder}" : summary
      end

      def compact_list_visual_items(limit: 3)
        list_items.first(limit)
      end

      def list_count
        list_items.count
      end

      def list_item_text(item)
        return item unless item.is_a?(Hash)

        item[:text] || item[:label]
      end

      def list_item_avatar_name(item)
        avatar = item[:avatar] if item.is_a?(Hash)
        return avatar[:name] || avatar["name"] if avatar.respond_to?(:[])
        return avatar if avatar.present?

        list_item_text(item)
      end

      def unit_label
        metadata_value(:unit_label)
      end

      def progress_value
        metadata_value(:progress_value)
      end

      def progress_max
        metadata_value(:progress_max) || 100
      end

      def progress_label
        metadata_value(:progress_label)
      end

      def progress_variant
        metadata_value(:progress_variant) || :default
      end

      def mini_chart_type
        self.class.renderable_chart_type(widget.chart_type.presence || :area, default: :area)
      end

      def chart_type(default: :line)
        self.class.renderable_chart_type(widget.chart_type, default: default)
      end

      def integer_ticks?
        self.class.integer_ticks?(chart_type, series: widget.series, chart_options: widget.chart_options)
      end

      def mini_chart_integer_ticks?
        self.class.integer_ticks?(
          mini_chart_type,
          series: widget.series,
          default: :area,
          chart_options: widget.chart_options
        )
      end

      def mini_chart_options
        return geo_mini_chart_options if geo_chart_type?(mini_chart_type)
        return pie_or_donut_mini_chart_options if %i[pie donut].include?(mini_chart_type.to_s.downcase.to_sym)
        return gauge_mini_chart_options if gauge_chart_type?(mini_chart_type)

        default_mini_chart_options.deep_merge(widget.chart_options || {})
      end

      def full_list_items
        list_items.first(FULL_LIST_LIMIT)
      end

      def change_text_class
        case RecordingStudioAdmin::WidgetChangeSemantics.tone(
          change: widget.change,
          good_when: widget.change_good_when
        )
        when :success
          "text-[var(--color-success-background-color)]"
        when :danger
          "text-[var(--color-danger-background-color)]"
        else
          "text-[var(--surface-muted-content-color)]"
        end
      end

      private

      attr_reader :widget, :link_policy

      def metric_value
        return widget.value if widget.value.present?

        list_count if widget.type == :list
      end

      def list_items
        Array(widget.items)
      end

      def compact_list_period_label
        period_label
      end

      def metadata_value(key)
        widget.metadata&.[](key).presence || widget.metadata&.[](key.to_s).presence
      end

      def compact_number(value)
        return unless value.is_a?(Numeric)

        absolute_value = value.abs
        suffixes = [
          [1_000_000_000_000, "T"],
          [1_000_000_000, "B"],
          [1_000_000, "M"],
          [1_000, "K"]
        ]
        threshold, suffix = suffixes.find { |candidate_threshold, _| absolute_value >= candidate_threshold }
        return unless threshold

        formatted = format("%.1f", value.to_f / threshold).sub(/\.0\z/, "")
        "#{formatted}#{suffix}"
      end

      def exact_number(value)
        number_string = defined?(BigDecimal) && value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
        match = number_string.match(/\A(?<sign>-?)(?<integer>\d+)(?<fraction>\.\d+)?\z/)
        return number_string unless match

        integer = match[:integer].reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
        "#{match[:sign]}#{integer}#{match[:fraction]}"
      end

      def gauge_mini_chart_options
        default_mini_chart_options.deep_merge(
          plotOptions: {
            radialBar: {
              dataLabels: {
                name: { show: false },
                value: { show: false }
              }
            }
          }
        ).deep_merge(widget.chart_options || {})
      end

      def pie_or_donut_mini_chart_options
        (widget.chart_options || {}).deep_merge(
          chart: { sparkline: { enabled: true }, toolbar: { show: false } },
          legend: { show: false },
          tooltip: { enabled: false },
          dataLabels: { enabled: false }
        )
      end

      def geo_mini_chart_options
        options = widget.chart_options || {}
        return options unless compact?

        options.deep_merge(legend: "none")
      end

      def default_mini_chart_options
        {
          chart: { sparkline: { enabled: true }, toolbar: { show: false } },
          markers: { size: 0 },
          tooltip: { enabled: false },
          grid: { show: false },
          xaxis: {
            labels: { show: false },
            axisBorder: { show: false },
            axisTicks: { show: false }
          },
          yaxis: { show: false },
          legend: { show: false },
          dataLabels: { enabled: false }
        }
      end

      def geo_chart_type?(value)
        value.to_s.downcase.to_sym == :geochart
      end

      def gauge_chart_type?(value)
        value.to_s.downcase.to_sym == :gauge
      end
    end
  end
end
