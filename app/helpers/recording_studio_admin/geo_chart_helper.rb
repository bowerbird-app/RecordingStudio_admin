# frozen_string_literal: true

module RecordingStudioAdmin
  module GeoChartHelper
    WORLD_MAP_ASSET_PATH = "/assets/recording_studio_admin/world_map_light.svg"

    COUNTRY_CENTROIDS = {
      "US" => [39.8283, -98.5795],
      "CA" => [56.1304, -106.3468],
      "MX" => [23.6345, -102.5528],
      "BR" => [-14.2350, -51.9253],
      "AR" => [-38.4161, -63.6167],
      "GB" => [55.3781, -3.4360],
      "IE" => [53.4129, -8.2439],
      "FR" => [46.2276, 2.2137],
      "DE" => [51.1657, 10.4515],
      "ES" => [40.4637, -3.7492],
      "IT" => [41.8719, 12.5674],
      "NL" => [52.1326, 5.2913],
      "SE" => [60.1282, 18.6435],
      "NO" => [60.4720, 8.4689],
      "PL" => [51.9194, 19.1451],
      "UA" => [48.3794, 31.1656],
      "TR" => [38.9637, 35.2433],
      "RU" => [61.5240, 105.3188],
      "EG" => [26.8206, 30.8025],
      "ZA" => [-30.5595, 22.9375],
      "NG" => [9.0820, 8.6753],
      "KE" => [-0.0236, 37.9062],
      "IN" => [20.5937, 78.9629],
      "PK" => [30.3753, 69.3451],
      "CN" => [35.8617, 104.1954],
      "JP" => [36.2048, 138.2529],
      "KR" => [35.9078, 127.7669],
      "SG" => [1.3521, 103.8198],
      "ID" => [-0.7893, 113.9213],
      "AU" => [-25.2744, 133.7751],
      "NZ" => [-40.9006, 174.8860]
    }.freeze

    def recording_studio_flatpack_geo_series(series)
      points = normalize_geo_series(series).filter_map do |entry|
        centroid = COUNTRY_CENTROIDS[entry[:code]]
        next unless centroid

        {
          x: centroid[1],
          y: centroid[0],
          meta: {
            code: entry[:code],
            value: entry[:value].to_i
          }
        }
      end

      [{ name: "Geo", data: points }]
    end

    def recording_studio_flatpack_geo_options(options = {}, marker_size: 8)
      {
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
        markers: {
          size: marker_size,
          strokeWidth: 0,
          fillOpacity: 0.8
        },
        stroke: { width: 0 },
        grid: {
          show: false,
          padding: { top: 0, right: 0, bottom: 0, left: 0 }
        },
        tooltip: {
          x: { show: false }
        },
        legend: { show: false },
        dataLabels: { enabled: false }
      }.deep_merge((options || {}).except(:geo))
    end

    def recording_studio_flatpack_geo_container_style
      "background-image:url('#{WORLD_MAP_ASSET_PATH}');background-repeat:no-repeat;background-size:100% 100%;background-position:center;"
    end

    private

    def normalize_geo_series(series)
      rows = if series.is_a?(Hash)
               Array(series[:data] || series["data"])
             else
               Array(series).flat_map { |item| Array(item[:data] || item["data"]) }
             end

      rows.map do |item|
        code = item[:x] || item["x"] || item[:code] || item["code"]
        value = item[:y] || item["y"] || item[:value] || item["value"]

        {
          code: code.to_s.strip.upcase,
          value: value.to_f
        }
      end
    end
  end
end