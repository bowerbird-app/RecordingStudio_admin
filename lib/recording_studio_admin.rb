# frozen_string_literal: true

require "recording_studio_admin/version"
require "recording_studio_admin/errors"
require "recording_studio_admin/surface"
require "recording_studio_admin/configuration"
require "recording_studio_admin/url_safety"
require "recording_studio_admin/recording_studio_accessible_compatibility"
require "recording_studio_admin/authorization"
require "recording_studio_admin/admin_action_audit"
require "recording_studio_admin/blast_radius"
require "recording_studio_admin/registry"
require "recording_studio_admin/results/query_result"
require "recording_studio_admin/results/table_result"
require "recording_studio_admin/results/resolved_objects"
require "recording_studio_admin/definitions/base"
require "recording_studio_admin/definitions/filter_definition"
require "recording_studio_admin/filters/date_range_filter"
require "recording_studio_admin/filters/group_by_filter"
require "recording_studio_admin/filters/select_filter"
require "recording_studio_admin/period"
require "recording_studio_admin/context"
require "recording_studio_admin/allows_admin_sections"
require "recording_studio_admin/admin_activity_logs_support"
require "recording_studio_admin/widget"
require "recording_studio_admin/widget_change_semantics"
require "recording_studio_admin/widgets/presenter"
require "recording_studio_admin/flat_pack_geo_chart_support"
require "recording_studio_admin/section"
require "recording_studio_admin/section_recording_resolver"
require "recording_studio_admin/admin_activity_logs_section"
require "recording_studio_admin/screen_filter_presentation"
require "recording_studio_admin/screen"
require "recording_studio_admin/admin_activity_logs_screen"
require "recording_studio_admin/admin_activity_logs_widget"
require "recording_studio_admin/resource"
require "recording_studio_admin/table_cell_renderer"
require "recording_studio_admin/resolvers/available_admin_items_resolver"
require "recording_studio_admin/resolvers/available_sections_resolver"
require "recording_studio_admin/resolvers/available_widgets_resolver"
require "recording_studio_admin/resolvers/sections_resolver"
require "recording_studio_admin/resolvers/section_resolver"
require "recording_studio_admin/resolvers/screen_resolver"
require "recording_studio_admin/resolvers/resource_resolver"
require "recording_studio_admin/resolvers/widget_resolver"
require "recording_studio_admin/routing" if defined?(Rails)
require "recording_studio_admin/engine" if defined?(Rails)

RecordingStudioAdmin::RecordingStudioAccessibleCompatibility.install!

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

    def register_resource(klass) = registry.register_resource(klass)
    def resource_for(key) = registry.resource_for(key)
    def resources = registry.resources.dup

    def available_admin_items(context:, recording: Resolvers::AvailableAdminItemsResolver::DEFAULT_RECORDING,
                              placement: :all, parent: nil, include: %i[sections screens])
      Resolvers::AvailableAdminItemsResolver.call(
        context: context,
        recording: recording,
        placement: placement,
        parent: parent,
        include: include
      )
    end

    def available_sections(context:, recording: Resolvers::AvailableSectionsResolver::DEFAULT_RECORDING,
                           placement: :all)
      Resolvers::AvailableSectionsResolver.call(context: context, recording: recording, placement: placement)
    end

    def available_widgets(context:, recording: Resolvers::AvailableWidgetsResolver::DEFAULT_RECORDING,
                          placement: :all, include: %i[section_widgets linked_screen_widgets])
      Resolvers::AvailableWidgetsResolver.call(
        context: context,
        recording: recording,
        placement: placement,
        include: include
      )
    end

    def enabled_admin_section_keys(recording:, context:)
      recordable = recording&.recordable if recording.respond_to?(:recordable)
      resolved_keys = resolve_configured_admin_sections(recording: recording, recordable: recordable, context: context)
      return normalize_admin_section_keys(resolved_keys) unless resolved_keys.nil?

      return unless recordable&.class.respond_to?(:recording_studio_admin_section_keys_for)

      recordable.class.recording_studio_admin_section_keys_for(recordable, recording, context)
    end

    def section_enabled?(key:, recording:, context:)
      enabled_keys = enabled_admin_section_keys(recording: recording, context: context)
      return true if enabled_keys.nil?

      enabled_keys.include?(key.to_s)
    end

    def screen_enabled?(key:, recording:, context:)
      enabled_keys = enabled_admin_section_keys(recording: recording, context: context)
      return true if enabled_keys.nil?

      enabled_sections = enabled_keys.filter_map do |enabled_key|
        definition = sections[enabled_key.to_s]
        definition if definition && definition_visible?(definition, context)
      end

      enabled_sections.any? do |definition|
        linked_screen_key_for(definition,
                              context) == key.to_s || linked_screen_keys_for(definition, context).include?(key.to_s)
      end
    end

    def normalize_admin_section_keys(keys)
      Array(keys).compact.map(&:to_s).uniq
    end

    def register_widget(widget) = registry.register_widget(widget)
    def widget_for(key) = registry.widget_for(key)

    def resolve_sections(context:) = Resolvers::SectionsResolver.call(context: context)

    def resolve_screen(key:, context:, resolve_widgets: true, resolve_summary: true, resolve_chart: true,
                       resolve_table: true, resolve_table_rows: true, resolve_table_count: true)
      Resolvers::ScreenResolver.call(
        key: key,
        context: context,
        resolve_widgets: resolve_widgets,
        resolve_summary: resolve_summary,
        resolve_chart: resolve_chart,
        resolve_table: resolve_table,
        resolve_table_rows: resolve_table_rows,
        resolve_table_count: resolve_table_count
      )
    end

    def resolve_section(key:, context:, resolve_widgets: true)
      Resolvers::SectionResolver.call(key: key, context: context, resolve_widgets: resolve_widgets)
    end

    def authorize_resource!(key:, context:, action:, record: nil, audit: false, audit_action: nil)
      Resolvers::ResourceResolver.call(key: key, context: context, action: action, record: record)
    rescue AuthorizationFailed, DefinitionNotFound => e
      if audit
        AdminActionAudit.record(
          resource_key: key,
          action_key: audit_action || action,
          context: context,
          record: record,
          outcome: :denied,
          error: e
        )
      end
      raise
    end
    alias resolve_resource_action authorize_resource!

    def resolve_table_resource_action(key:, context:, action:)
      Resolvers::ResourceResolver.call(
        key: key,
        context: context,
        action: action,
        enforce_record_visibility: false
      )
    end

    def resolve_widget(key:, context:) = Resolvers::WidgetResolver.call(key: key, context: context)

    private

    def resolve_configured_admin_sections(recording:, recordable:, context:)
      resolver = configuration.admin_sections_resolver
      return unless resolver

      if keyword_resolver?(resolver)
        return resolver.call(recording: recording, recordable: recordable, context: context)
      end

      positional_resolver_call(resolver, recording, recordable, context)
    end

    def positional_resolver_call(resolver, recording, recordable, context)
      case resolver.arity
      when 0 then resolver.call
      when 1, -1 then resolver.call(recording)
      when 2 then resolver.call(recording, context)
      else resolver.call(recording, recordable, context)
      end
    end

    def keyword_resolver?(resolver)
      resolver.parameters.any? { |type, _name| %i[key keyreq].include?(type) }
    end

    def definition_visible?(definition, context)
      return true unless definition.visible_if

      definition.visible_if.call(context)
    end

    def linked_screen_keys_for(definition, context)
      definition.links.filter_map do |link|
        resolved_link = link.resolve(context)
        next unless resolved_link

        screen_definition_for_path(resolved_link.url, context)&.key&.to_s
      end.uniq
    end

    def linked_screen_key_for(definition, context)
      linked_screen_keys_for(definition, context).first
    end

    def screen_definition_for_path(url, context)
      link_path = url.to_s.split("?").first
      screens.values.find do |definition|
        context.admin_screen_path(definition.key).to_s.split("?").first == link_path
      end
    end
  end
end
