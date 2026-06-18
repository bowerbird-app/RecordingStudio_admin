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
end