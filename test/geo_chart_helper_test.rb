# frozen_string_literal: true

require "test_helper"
require_relative "../app/helpers/recording_studio_admin/geo_chart_helper"

class GeoChartHelperTest < Minitest::Test
  class GeoHelperHost
    include RecordingStudioAdmin::GeoChartHelper
  end

  def test_geochart_series_normalizes_legacy_code_and_xy_points
    helper = GeoHelperHost.new

    series = [
      {
        name: "User activities",
        data: [
          { x: "US", y: 10 },
          { code: "GB", value: 4 }
        ]
      }
    ]

    normalized = helper.recording_studio_flatpack_geochart_series(series)

    assert_equal "User activities", normalized.first[:name]
    assert_equal({ region: "US", value: 10.0 }, normalized.first[:data].first)
    assert_equal({ region: "GB", value: 4.0 }, normalized.first[:data].last)
  end

  def test_geochart_series_keeps_existing_region_value_points
    helper = GeoHelperHost.new

    series = [
      {
        name: "User activities",
        data: [
          { region: "United States", value: 12 },
          { region: "Canada", value: 7 }
        ]
      }
    ]

    normalized = helper.recording_studio_flatpack_geochart_series(series)

    assert_equal({ region: "United States", value: 12.0 }, normalized.first[:data].first)
    assert_equal({ region: "Canada", value: 7.0 }, normalized.first[:data].last)
  end

  def test_geochart_options_use_google_safe_colors_and_strip_legacy_geo_and_chart_keys
    helper = GeoHelperHost.new

    options = helper.recording_studio_flatpack_geochart_options(
      {
        geo: { map: "world", key_field: "iso2" },
        chart: { height: 260 },
        colorAxis: { minValue: 0 }
      }
    )

    assert_equal "world", options[:region]
    assert_equal "regions", options[:displayMode]
    assert_equal "countries", options[:resolution]
    refute_includes options.keys, :geo
    refute_includes options.keys, :chart

    assert_equal "#e5e7eb", options[:datalessRegionColor]
    assert_equal "#9ca3af", options[:defaultColor]
    assert_equal ["#e5e7eb", "#9ca3af", "#4b5563"], options.dig(:colorAxis, :colors)
    assert_equal 0, options.dig(:colorAxis, :minValue)
  end
end
