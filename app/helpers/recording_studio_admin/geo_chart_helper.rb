# frozen_string_literal: true

module RecordingStudioAdmin
  module GeoChartHelper
    def recording_studio_flatpack_geochart_series(series)
      normalized_series = normalize_geochart_series(series)
      return normalized_series if normalized_series.any?

      series
    end

    def recording_studio_flatpack_geochart_options(options = {})
      normalized = (options || {}).to_h.deep_symbolize_keys
      legacy_geo = normalized.delete(:geo) || {}
      normalized.delete(:chart)

      region = normalized[:region] || legacy_geo[:map] || "world"

      {
        region: region,
        displayMode: "regions",
        resolution: "countries",
        backgroundColor: { fill: "transparent" },
        datalessRegionColor: "#e5e7eb",
        defaultColor: "#9ca3af",
        colorAxis: {
          colors: ["#e5e7eb", "#9ca3af", "#4b5563"]
        },
        legend: {
          textStyle: { color: "#334155" }
        },
        tooltip: {
          textStyle: { color: "#111827" }
        }
      }.deep_merge(normalized)
    end

    private

    def normalize_geochart_series(series)
      Array(series).filter_map do |entry|
        next unless entry.respond_to?(:to_h)

        series_entry = entry.to_h.deep_symbolize_keys
        raw_points = Array(series_entry[:data])
        next if raw_points.empty?

        normalized_points = raw_points.filter_map { |point| normalize_geochart_point(point) }
        next if normalized_points.empty?

        series_entry.merge(data: normalized_points)
      end
    end

    def normalize_geochart_point(point)
      if point.is_a?(Array)
        region = point[0]
        value = point[1]
      elsif point.respond_to?(:to_h)
        point_data = point.to_h.deep_symbolize_keys
        region = point_data[:region] || point_data[:code] || point_data[:x] || point_data[:name] || point_data[:country]
        value = point_data[:value] || point_data[:val] || point_data[:count] || point_data[:y] || point_data[:data]
      else
        return nil
      end

      return nil if region.blank? || value.nil?

      numeric_value = begin
        Float(value)
      rescue StandardError
        nil
      end
      return nil unless numeric_value

      {
        region: region.to_s,
        value: numeric_value
      }
    end
  end
end
