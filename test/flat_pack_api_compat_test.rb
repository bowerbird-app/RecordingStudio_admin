# frozen_string_literal: true

require "test_helper"

class FlatPackApiCompatTest < Minitest::Test
  def test_page_nav_maps_legacy_anchor_and_back_url_kwargs
    component_class = Class.new do
      attr_reader :kwargs

      def initialize(**kwargs)
        @kwargs = kwargs
      end
    end
    component_class.prepend(RecordingStudioAdmin::FlatPackApiCompat::PageNavInitialize)

    component = component_class.new(anchor_url: "https://example.test/origin", back_url: "/previous")

    assert_equal "https://example.test/origin", component.kwargs[:anchor_href]
    assert_equal "/previous", component.kwargs[:secondary_anchor_href]
    refute component.kwargs.key?(:anchor_url)
    refute component.kwargs.key?(:back_url)
  end

  def test_sidebar_item_maps_legacy_label_to_text
    component_class = Class.new do
      attr_reader :kwargs

      def initialize(**kwargs)
        @kwargs = kwargs
      end
    end
    component_class.prepend(RecordingStudioAdmin::FlatPackApiCompat::SidebarItemInitialize)

    component = component_class.new(label: "Home", href: "/")

    assert_equal "Home", component.kwargs[:text]
    refute component.kwargs.key?(:label)
  end

  def test_button_maps_legacy_url_to_href
    component_class = Class.new do
      attr_reader :kwargs

      def initialize(**kwargs)
        @kwargs = kwargs
      end
    end
    component_class.prepend(RecordingStudioAdmin::FlatPackApiCompat::ButtonInitialize)

    component = component_class.new(text: "Open", url: "/admin")

    assert_equal "/admin", component.kwargs[:href]
    refute component.kwargs.key?(:url)
  end
end
