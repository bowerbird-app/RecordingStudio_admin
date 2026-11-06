# frozen_string_literal: true

require "test_helper"
require_relative "../app/helpers/recording_studio_admin/page_nav_helper"

class PageNavHelperTest < Minitest::Test
  class PageNavRecorder
    attr_reader :items

    def initialize
      @items = []
    end

    def with_back(**options)
      @items << [:back, options]
    end

    def with_close(**options)
      @items << [:close, options]
    end
  end

  class PageNavHelperHost
    include RecordingStudioAdmin::PageNavHelper

    attr_reader :page_nav_kwargs, :page_nav_items, :titles, :subtitles

    def initialize
      @titles = []
      @subtitles = []
    end

    def content_for(name, value = nil)
      @titles << value if name == :title
      @subtitles << value if name == :subtitle
      nil
    end

    def t(_key, default:)
      default
    end

    def flat_pack_page_nav(**kwargs)
      recorder = PageNavRecorder.new
      yield recorder
      @page_nav_kwargs = kwargs
      @page_nav_items = recorder.items
      nil
    end
  end

  def test_page_heading_uses_with_back_and_with_close_when_anchor_present
    helper = PageNavHelperHost.new

    helper.recording_studio_admin_page_heading(
      title: "Admin",
      subtitle: "Staff home",
      anchor: "https://example.test/app"
    )

    assert_equal ["Admin"], helper.titles
    assert_equal ["Staff home"], helper.subtitles
    assert_equal({ round: true, style: :default }, helper.page_nav_kwargs)
    assert_equal(
      [
        [:back, { tooltip: "Go back", fallback_url: "https://example.test/app" }],
        [:close, { href: "https://example.test/app", tooltip: "Close" }]
      ],
      helper.page_nav_items
    )
  end

  def test_page_heading_omits_close_when_anchor_blank
    helper = PageNavHelperHost.new

    helper.recording_studio_admin_page_heading(title: "Admin", anchor: nil)

    assert_equal({ round: true, style: :default }, helper.page_nav_kwargs)
    assert_equal(
      [[:back, { tooltip: "Go back" }]],
      helper.page_nav_items
    )
  end

  def test_page_nav_role_maps_button_styles
    helper = PageNavHelperHost.new

    assert_equal :primary, helper.recording_studio_admin_page_nav_role("primary")
    assert_equal :destructive, helper.recording_studio_admin_page_nav_role(:danger)
    assert_equal :secondary, helper.recording_studio_admin_page_nav_role(:ghost)
  end
end
