# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class AvailableAdminItemsResolver
      VALID_PLACEMENTS = %i[all root descendant].freeze
      VALID_INCLUDES = %i[sections screens].freeze
      DEFAULT_RECORDING = :__recording_studio_admin_default__

      def self.call(context:, recording: DEFAULT_RECORDING, placement: :all, parent: nil, include: %i[sections screens])
        new(context: context, recording: recording, placement: placement, parent: parent, include: include).call
      end

      def initialize(context:, recording:, placement:, parent:, include:)
        @context = context
        @recording = recording == DEFAULT_RECORDING ? context.access_recording : recording
        @placement = normalize_placement(placement)
        @parent = parent&.to_s
        @include = normalize_include(include)
      end

      def call
        RecordingStudioAdmin::Authorization.authorize!(@context, recording: @recording)

        enabled_keys = RecordingStudioAdmin.enabled_admin_section_keys(recording: @recording, context: @context)
        return available_enabled_items(enabled_keys) if enabled_keys

        items = []
        items.concat(section_items) if @include.include?(:sections)
        items.concat(screen_items) if @include.include?(:screens)

        scoped_items = filter_by_parent(items)
        scoped_items.sort_by { |item| [item.title.to_s, item.key.to_s] }
      end

      private

      def available_enabled_items(enabled_keys)
        enabled_sections = enabled_keys.filter_map do |key|
          definition = RecordingStudioAdmin.sections[key.to_s]
          definition if definition && visible?(definition) && blast_radius_allowed?(definition)
        end

        items = []
        if @include.include?(:sections)
          items.concat(enabled_sections.map do |definition|
            build_item(definition, type: :section, url: @context.admin_section_path(definition.key))
          end)
        end
        if @include.include?(:screens)
          items.concat(enabled_sections.flat_map { |definition| link_items_for(definition) })
        end

        scoped_items = filter_by_parent(items.compact)
        scoped_items.sort_by { |item| [item.title.to_s, item.key.to_s] }
      end

      def link_items_for(definition)
        definition.links.filter_map do |link|
          build_link_item(definition, link)
        end
      end

      def build_link_item(definition, link)
        resolved_link = link.resolve(@context)
        return unless resolved_link

        screen_definition = screen_definition_for_link(resolved_link)
        return if screen_definition && !blast_radius_allowed?(screen_definition, container: definition)

        title = link_item_title(resolved_link, screen_definition)
        return if title.blank?

        Results::ResolvedAvailableAdminItem.new(
          type: :screen,
          key: screen_definition&.key || "#{definition.key}.#{resolved_link.name}",
          title: title,
          subtitle: link_item_subtitle(definition, screen_definition),
          icon: screen_definition&.evaluate(screen_definition.icon, @context),
          url: resolved_link.url,
          parent_key: definition.key,
          availability_scope: availability_scope_label(definition),
          search_text: link_item_search_text(definition, resolved_link, title, screen_definition)
        )
      end

      def link_item_title(resolved_link, screen_definition)
        if screen_definition
          screen_definition.evaluate(screen_definition.title, @context).to_s
        else
          resolved_link.text.to_s
        end
      end

      def link_item_subtitle(definition, screen_definition)
        if screen_definition
          screen_definition.evaluate(screen_definition.subtitle, @context)
        else
          definition.evaluate(definition.title, @context)
        end
      end

      def link_item_search_text(definition, resolved_link, title, screen_definition)
        [
          :screen,
          definition.key,
          resolved_link.name,
          title,
          screen_definition&.subtitle
        ].compact.join(" ").downcase
      end

      def screen_definition_for_link(resolved_link)
        link_path = resolved_link.url.to_s.split("?").first
        RecordingStudioAdmin.screens.values.find do |definition|
          @context.admin_screen_path(definition.key).to_s.split("?").first == link_path
        end
      end

      def normalize_placement(value)
        normalized = value.to_s.downcase.to_sym
        return normalized if VALID_PLACEMENTS.include?(normalized)

        raise ArgumentError, "placement must be one of #{VALID_PLACEMENTS.join(', ')}"
      end

      def normalize_include(value)
        normalized = Array(value).map { |entry| entry.to_s.downcase.to_sym }.uniq
        unknown = normalized - VALID_INCLUDES
        raise ArgumentError, "include must be drawn from #{VALID_INCLUDES.join(', ')}" if unknown.any?

        normalized
      end

      def section_items
        RecordingStudioAdmin.sections.values.filter_map do |definition|
          next unless visible?(definition)
          next unless available_for_placement?(definition)
          next unless blast_radius_allowed?(definition)

          build_item(definition, type: :section, url: @context.admin_section_path(definition.key))
        end
      end

      def screen_items
        RecordingStudioAdmin.screens.values.filter_map do |definition|
          next unless visible?(definition)
          next unless available_for_placement?(definition)
          next unless blast_radius_allowed?(definition)

          build_item(definition, type: :screen, url: @context.admin_screen_path(definition.key))
        end
      end

      def build_item(definition, type:, url:)
        title = definition.evaluate(definition.title, @context)
        return if title.blank?

        subtitle = definition.evaluate(definition.subtitle, @context)

        Results::ResolvedAvailableAdminItem.new(
          type: type,
          key: definition.key,
          title: title,
          subtitle: subtitle,
          icon: definition.evaluate(definition.icon, @context),
          url: url,
          parent_key: nil,
          availability_scope: availability_scope_label(definition),
          search_text: [type, definition.key, title, subtitle].compact.join(" ").downcase
        )
      end

      def filter_by_parent(items)
        return items if @parent.blank?

        parent_lookup = items.each_with_object({}) do |item, lookup|
          lookup[item.key.to_s] = item.parent_key&.to_s
        end

        items.select { |item| descendant_of_parent?(item.parent_key, parent_lookup) }
      end

      def descendant_of_parent?(candidate_parent, parent_lookup)
        current_key = candidate_parent&.to_s
        visited = {}

        while current_key.present? && !visited[current_key]
          return true if current_key == @parent

          visited[current_key] = true
          current_key = parent_lookup[current_key]
        end

        false
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end

      def blast_radius_allowed?(definition, container: nil)
        RecordingStudioAdmin::BlastRadius.allowed?(definition, context: @context, recording: @recording,
                                                               container: container)
      end

      def available_for_placement?(definition)
        scope = definition.availability_scope
        return custom_scope_matches?(scope) if scope.respond_to?(:call)
        return true if @placement == :all

        case scope
        when :all
          true
        when :root
          @placement == :root && root_recording?(@recording)
        when :descendant
          @placement == :descendant && descendant_recording?(@recording)
        else
          false
        end
      end

      def availability_scope_label(definition)
        scope = definition.availability_scope
        scope.respond_to?(:call) ? :custom : scope
      end

      def custom_scope_matches?(callable)
        case callable.arity
        when 0 then callable.call
        when 1, -1 then callable.call(@recording)
        when 2 then callable.call(@recording, @context)
        else callable.call(@recording, @context, @placement)
        end
      end

      def root_recording?(recording)
        return false unless recording
        return recording.parent_recording.nil? if recording.respond_to?(:parent_recording)
        if recording.respond_to?(:root_recording) && recording.root_recording
          return recording.root_recording.equal?(recording)
        end

        RecordingStudio.root_recording_or_self(recording).equal?(recording)
      end

      def descendant_recording?(recording)
        return false unless recording
        return recording.parent_recording.present? if recording.respond_to?(:parent_recording)
        if recording.respond_to?(:root_recording) && recording.root_recording
          return !recording.root_recording.equal?(recording)
        end

        !root_recording?(recording)
      end
    end
  end
end
