# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class AvailableSectionsResolver
      VALID_PLACEMENTS = %i[all root descendant].freeze
      DEFAULT_RECORDING = :__recording_studio_admin_default__

      def self.call(context:, recording: DEFAULT_RECORDING, placement: :all)
        new(context: context, recording: recording, placement: placement).call
      end

      def initialize(context:, recording:, placement:)
        @context = context
        @recording = recording == DEFAULT_RECORDING ? context.access_recording : recording
        @placement = normalize_placement(placement)
      end

      def call
        RecordingStudioAdmin::Authorization.authorize!(@context, recording: @recording)

        enabled_keys = RecordingStudioAdmin.enabled_admin_section_keys(recording: @recording, context: @context)
        return available_enabled_sections(enabled_keys) if enabled_keys

        available_legacy_sections
      end

      private

      def available_enabled_sections(enabled_keys)
        enabled_keys.filter_map do |key|
          definition = RecordingStudioAdmin.sections[key.to_s]
          next unless definition
          next unless visible?(definition)

          build_section(definition)
        end.sort_by { |section| [section.title.to_s, section.key.to_s] }
      end

      def available_legacy_sections
        RecordingStudioAdmin.sections.values.filter_map do |definition|
          next unless visible?(definition)
          next unless available_for_placement?(definition)

          build_section(definition)
        end.sort_by { |section| [section.title.to_s, section.key.to_s] }
      end

      def build_section(definition)
        Results::ResolvedAvailableSection.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          icon: definition.evaluate(definition.icon, @context),
          url: @context.admin_section_path(definition.key),
          availability_scope: availability_scope_label(definition)
        )
      end

      def normalize_placement(value)
        normalized = value.to_s.downcase.to_sym
        return normalized if VALID_PLACEMENTS.include?(normalized)

        raise ArgumentError, "placement must be one of #{VALID_PLACEMENTS.join(', ')}"
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
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
