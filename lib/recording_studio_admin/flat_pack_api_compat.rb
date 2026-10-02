# frozen_string_literal: true

module RecordingStudioAdmin
  # Compatibility shims for FlatPack keyword renames that RecordingStudio layouts
  # and older host call sites still use (anchor_url→anchor_href, label→text, url→href).
  module FlatPackApiCompat
    module PageNavInitialize
      def initialize(**kwargs)
        if kwargs.key?(:anchor_url) && !kwargs.key?(:anchor_href)
          kwargs[:anchor_href] = kwargs.delete(:anchor_url)
        end
        if kwargs.key?(:secondary_anchor_url) && !kwargs.key?(:secondary_anchor_href)
          kwargs[:secondary_anchor_href] = kwargs.delete(:secondary_anchor_url)
        end
        if kwargs.key?(:back_url) && !kwargs.key?(:secondary_anchor_href)
          kwargs[:secondary_anchor_href] = kwargs.delete(:back_url)
        else
          kwargs.delete(:back_url)
        end

        super(**kwargs)
      end
    end

    module SidebarItemInitialize
      def initialize(**kwargs)
        if kwargs.key?(:label) && !kwargs.key?(:text)
          kwargs[:text] = kwargs.delete(:label)
        end

        super(**kwargs)
      end
    end

    module ButtonInitialize
      def initialize(**kwargs)
        if kwargs.key?(:url) && !kwargs.key?(:href)
          kwargs[:href] = kwargs.delete(:url)
        end

        super(**kwargs)
      end
    end

    def self.install!
      install_page_nav!
      install_sidebar_item!
      install_button!
    end

    def self.install_page_nav!
      return unless defined?(FlatPack::PageNav::Component)

      component = FlatPack::PageNav::Component
      return if component.ancestors.include?(PageNavInitialize)

      component.prepend(PageNavInitialize)
    end

    def self.install_sidebar_item!
      return unless defined?(FlatPack::Sidebar::Item::Component)

      component = FlatPack::Sidebar::Item::Component
      return if component.ancestors.include?(SidebarItemInitialize)

      component.prepend(SidebarItemInitialize)
    end

    def self.install_button!
      return unless defined?(FlatPack::Button::Component)

      component = FlatPack::Button::Component
      return if component.ancestors.include?(ButtonInitialize)

      component.prepend(ButtonInitialize)
    end
  end
end

RecordingStudioAdmin::FlatPackApiCompat.install!
