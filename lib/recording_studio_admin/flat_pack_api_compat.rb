# frozen_string_literal: true

module RecordingStudioAdmin
  # Compatibility shims for FlatPack keyword renames that RecordingStudio layouts
  # and older host call sites still use (anchor_url→anchor_href, label→text, url→href).
  module FlatPackApiCompat
    module PageNavInitialize
      def initialize(**kwargs)
        remap_alias!(kwargs, :anchor_url, :anchor_href)
        remap_alias!(kwargs, :secondary_anchor_url, :secondary_anchor_href)
        remap_back_url!(kwargs)
        super
      end

      private

      def remap_alias!(kwargs, from, to)
        kwargs[to] = kwargs.delete(from) if kwargs.key?(from) && !kwargs.key?(to)
      end

      def remap_back_url!(kwargs)
        if kwargs.key?(:back_url) && !kwargs.key?(:secondary_anchor_href)
          kwargs[:secondary_anchor_href] = kwargs.delete(:back_url)
        else
          kwargs.delete(:back_url)
        end
      end
    end

    module SidebarItemInitialize
      def initialize(**kwargs)
        kwargs[:text] = kwargs.delete(:label) if kwargs.key?(:label) && !kwargs.key?(:text)
        super
      end
    end

    module ButtonInitialize
      def initialize(**kwargs)
        kwargs[:href] = kwargs.delete(:url) if kwargs.key?(:url) && !kwargs.key?(:href)
        super
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
