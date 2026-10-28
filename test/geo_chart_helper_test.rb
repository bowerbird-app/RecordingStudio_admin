# frozen_string_literal: true

require "test_helper"
require_relative "../app/helpers/recording_studio_admin/geo_chart_helper"

class GeoChartHelperTest < Minitest::Test
  class GeoHelperHost
    include RecordingStudioAdmin::GeoChartHelper
  end

  def test_series_normalizes_hash_data_and_filters_unknown_country_codes
    helper = GeoHelperHost.new
    series = {
      data: [
        { x: "us", y: 5.7 },
        { code: "XX", value: 12 }
      ]
    }

    resolved = helper.recording_studio_flatpack_geo_series(series)

    assert_equal "Geo", resolved.first[:name]
    assert_equal 1, resolved.first[:data].size
    first = resolved.first[:data].first
    assert_equal(-98.5795, first[:x])
    assert_equal 39.8283, first[:y]
    assert_equal "US", first.dig(:meta, :code)
    assert_equal 5, first.dig(:meta, :value)
  end

  def test_series_normalizes_array_data_with_string_keys
    helper = GeoHelperHost.new
    series = [
      {
        "data" => [
          { "code" => "ca", "value" => 3 },
          { "x" => "nz", "y" => 2 }
        ]
      }
    ]

    resolved = helper.recording_studio_flatpack_geo_series(series)

    assert_equal 2, resolved.first[:data].size
    assert_equal "CA", resolved.first[:data].first.dig(:meta, :code)
    assert_equal "NZ", resolved.first[:data].last.dig(:meta, :code)
  end

  def test_geo_options_remove_geo_key_and_merge_overrides
    helper = GeoHelperHost.new

    options = helper.recording_studio_flatpack_geo_options(
      { geo: { map: "world" }, chart: { toolbar: { show: true } }, custom: true },
      marker_size: 10
    )

    assert_equal 10, options.dig(:markers, :size)
    assert_equal true, options[:custom]
    assert_equal true, options.dig(:chart, :toolbar, :show)
    refute_includes options.keys, :geo
  end

  def test_geo_container_style_points_to_packaged_world_map
    helper = GeoHelperHost.new

    style = helper.recording_studio_flatpack_geo_container_style

    assert_includes style, RecordingStudioAdmin::GeoChartHelper::WORLD_MAP_ASSET_PATH
    assert_includes style, "background-repeat:no-repeat"
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
