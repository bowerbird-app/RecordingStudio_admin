# frozen_string_literal: true

module RecordingStudioAdmin
  module FlatPackGeoChartSupport
    def self.install!
      return unless defined?(FlatPack::Chart::Component)

      component = FlatPack::Chart::Component
      return if component.ancestors.include?(RecordingStudioAdmin::FlatPackGeoChartSupport)

      component.prepend(RecordingStudioAdmin::FlatPackGeoChartSupport)
    end

    def validate_type!
      return if @type == :geo

      super
    end

    def apex_chart_type
      return :scatter if geo_chart?

      super
    end

    def default_options
      return super unless geo_chart?

      super.deep_merge(geo_chart_defaults)
    end

    private

    def geo_chart?
      @type == :geo
    end

    def geo_chart_defaults
      {
        chart: {
          zoom: { enabled: false },
          toolbar: { show: false },
          animations: { enabled: false },
          foreColor: "var(--surface-muted-content-color)"
        },
        stroke: { width: 0 },
        markers: {
          size: 8,
          strokeWidth: 0,
          fillOpacity: 0.8,
          hover: { sizeOffset: 2 }
        },
        xaxis: {
          min: -180,
          max: 180,
          tickAmount: 12,
          labels: { show: false },
          axisBorder: { show: false },
          axisTicks: { show: false }
        },
        yaxis: {
          min: -90,
          max: 90,
          tickAmount: 6,
          labels: { show: false }
        },
        grid: {
          show: false,
          padding: { top: 0, right: 0, bottom: 0, left: 0 }
        },
        tooltip: { x: { show: false } },
        legend: { show: false },
        dataLabels: { enabled: false }
      }
    end
  end
end

RecordingStudioAdmin::FlatPackGeoChartSupport.install!
