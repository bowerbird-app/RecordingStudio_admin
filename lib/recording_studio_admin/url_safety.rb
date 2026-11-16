# frozen_string_literal: true

require "uri"

module RecordingStudioAdmin
  module UrlSafety
    SAFE_SCHEMES = %w[http https mailto].freeze
    UNSAFE_HREF = /\\|[[:cntrl:]]|[[:space:]]/

    module_function

    def safe_href(value, allow_external: false)
      href = value.to_s.strip
      return if href.empty?
      return "#" if unsafe_href?(href)
      return href if relative_href?(href)
      return "#" unless allow_external

      external_href(href)
    end

    def unsafe_href?(href)
      href.match?(UNSAFE_HREF)
    end
    private_class_method :unsafe_href?

    def relative_href?(href)
      href.start_with?("/") && !href.start_with?("//")
    end
    private_class_method :relative_href?

    def external_href(href)
      uri = URI.parse(href)
      return href if uri.scheme && SAFE_SCHEMES.include?(uri.scheme)

      "#"
    rescue URI::InvalidURIError
      "#"
    end
    private_class_method :external_href
  end
end
