# frozen_string_literal: true

module RecordingStudioAdmin
  SectionRecordableDefinition = Data.define(:class_name, :find_or_create_by, :parent, :parent_recording, :action)
  SectionWidgetUsage = Data.define(:key, :view_variant)
  SECTION_WIDGET_VIEW_VARIANTS = %i[card chip].freeze

  class Section < Definitions::Base
    class << self
      attr_reader :links_value, :widget_keys_value, :recordable_definition_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@links_value, [])
        subclass.instance_variable_set(:@widget_keys_value, [])
        subclass.instance_variable_set(:@recordable_definition_value, nil)
      end

      def link(name, text:, url:, style: :secondary, visible_if: nil)
        @links_value << Definitions::ButtonDefinition.new(name.to_sym, text, url, style, visible_if)
      end

      def widget(key, view_variant: nil)
        normalized_view_variant = view_variant.nil? ? nil : normalize_view_variant(view_variant)
        @widget_keys_value << SectionWidgetUsage.new(key: key.to_s, view_variant: normalized_view_variant)
      end

      def recordable(class_name, find_or_create_by:, parent: nil, parent_recording: nil, action: "created")
        raise ArgumentError, "parent or parent_recording is required" unless parent || parent_recording

        @recordable_definition_value = SectionRecordableDefinition.new(
          class_name: class_name,
          find_or_create_by: find_or_create_by,
          parent: parent,
          parent_recording: parent_recording,
          action: action
        )
      end

      def links
        @links_value || []
      end

      def widget_keys
        widget_usages.map(&:key)
      end

      def widget_usages
        (@widget_keys_value || []).map do |entry|
          if entry.is_a?(SectionWidgetUsage)
            entry
          else
            SectionWidgetUsage.new(key: entry.to_s, view_variant: nil)
          end
        end
      end

      def recordable_definition
        @recordable_definition_value
      end
    end

    def self.normalize_view_variant(value)
      normalized = value.to_s.downcase.to_sym
      return normalized if SECTION_WIDGET_VIEW_VARIANTS.include?(normalized)

      raise InvalidDefinition, "Section widget has unsupported view_variant #{value.inspect}"
    end
  end
end
