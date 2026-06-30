# frozen_string_literal: true

module RecordingStudioAdmin
  module Widgets
    class Presenter
      SUPPORTED_CHART_TYPES = %i[line column bar area donut pie radar gauge geochart].freeze
      CHART_TYPE_ALIASES = {
        geo: :geochart
      }.freeze

      def self.renderable_chart_type(type, default: :line)
        normalized = (type || default).to_s.downcase.to_sym
        normalized = CHART_TYPE_ALIASES.fetch(normalized, normalized)
        return normalized if SUPPORTED_CHART_TYPES.include?(normalized)

        :bar
      end

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
        return widget.value if widget.value.present?

        list_count if widget.type == :list
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

      def mini_chart_options
        return geo_mini_chart_options if geo_chart_type?(mini_chart_type)
        return pie_or_donut_mini_chart_options if %i[pie donut].include?(mini_chart_type.to_s.downcase.to_sym)

        default_mini_chart_options.deep_merge(widget.chart_options || {})
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

      def list_items
        Array(widget.items)
      end

      def compact_list_period_label
        period_label
      end

      def metadata_value(key)
        widget.metadata&.[](key).presence || widget.metadata&.[](key.to_s).presence
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
    end
  end
end
