# frozen_string_literal: true

require "test_helper"

class UrlSafetyTest < Minitest::Test
  def test_allows_relative_urls_by_default
    assert_equal "/admin", RecordingStudioAdmin::UrlSafety.safe_href("/admin")
    assert_equal "/admin?tab=overview#top", RecordingStudioAdmin::UrlSafety.safe_href(" /admin?tab=overview#top ")
  end

  def test_rejects_external_urls_by_default
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("https://example.com")
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("mailto:ops@example.com")
  end

  def test_allows_approved_external_urls_when_explicitly_enabled
    assert_equal "https://example.com",
                 RecordingStudioAdmin::UrlSafety.safe_href("https://example.com", allow_external: true)
    assert_equal "mailto:ops@example.com",
                 RecordingStudioAdmin::UrlSafety.safe_href("mailto:ops@example.com", allow_external: true)
  end

  def test_rejects_unsafe_or_blank_urls
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("javascript:alert(1)")
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href(" javascript:alert(1)")
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("JAVASCRIPT:alert(1)", allow_external: true)
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("//example.com")
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("https://[::1", allow_external: true)
    assert_nil RecordingStudioAdmin::UrlSafety.safe_href(nil)
  end
end
