# frozen_string_literal: true

require "uri"

module RecordingStudioAdmin
  module UrlSafety
    SAFE_SCHEMES = %w[http https mailto].freeze

    module_function

    def safe_href(value, allow_external: false)
      href = value.to_s.strip
      return if href.empty?
      return href if href.start_with?("/") && !href.start_with?("//")

      return "#" unless allow_external

      uri = URI.parse(href)
      return href if uri.scheme && SAFE_SCHEMES.include?(uri.scheme)

      "#"
    rescue URI::InvalidURIError
      "#"
    end
  end
end
