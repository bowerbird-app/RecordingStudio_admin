# frozen_string_literal: true

require "recording_studio_admin/version"
require "recording_studio_admin/errors"
require "recording_studio_admin/configuration"
require "recording_studio_admin/registry"
require "recording_studio_admin/results/query_result"
require "recording_studio_admin/results/table_result"
require "recording_studio_admin/results/resolved_objects"
require "recording_studio_admin/definitions/base"
require "recording_studio_admin/definitions/filter_definition"
require "recording_studio_admin/filters/date_range_filter"
require "recording_studio_admin/filters/group_by_filter"
require "recording_studio_admin/filters/select_filter"
require "recording_studio_admin/context"
require "recording_studio_admin/widget"
require "recording_studio_admin/section"
require "recording_studio_admin/screen"
require "recording_studio_admin/resolvers/section_resolver"
require "recording_studio_admin/resolvers/screen_resolver"
require "recording_studio_admin/resolvers/widget_resolver"
require "recording_studio_admin/engine" if defined?(Rails)

module RecordingStudioAdmin
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def registry
      @registry ||= Registry.new
    end

    def register_screen(klass) = registry.register_screen(klass)
    def screen_for(key) = registry.screen_for(key)
    def screens = registry.screens.dup

    def register_section(klass) = registry.register_section(klass)
    def section_for(key) = registry.section_for(key)
    def sections = registry.sections.dup

    def register_widget(widget) = registry.register_widget(widget)
    def widget_for(key) = registry.widget_for(key)

    def resolve_screen(key:, context:) = Resolvers::ScreenResolver.call(key: key, context: context)
    def resolve_section(key:, context:) = Resolvers::SectionResolver.call(key: key, context: context)
    def resolve_widget(key:, context:) = Resolvers::WidgetResolver.call(key: key, context: context)
  end
end
