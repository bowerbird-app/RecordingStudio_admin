# frozen_string_literal: true

module RecordingStudioAdmin
  module Widgets
    class Presenter
      SUPPORTED_CHART_TYPES = %i[line column bar area donut pie radar gauge geo].freeze

      def self.renderable_chart_type(type, default: :line)
        normalized = (type || default).to_s.downcase.to_sym
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
        period_label unless widget.type == :progress
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

      def default_mini_chart_options
        {
          chart: { sparkline: { enabled: true }, toolbar: { show: false } },
          stroke: { curve: "smooth", width: 2 },
          fill: {
            type: "gradient",
            gradient: {
              shade: "light",
              shadeIntensity: 0,
              inverseColors: false,
              opacityFrom: 0.45,
              opacityTo: 0.05,
              stops: [0, 90, 100]
            }
          },
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
    end
  end
end