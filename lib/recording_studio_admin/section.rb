# frozen_string_literal: true

module RecordingStudioAdmin
  SectionRecordableDefinition = Data.define(:class_name, :find_or_create_by, :parent, :parent_recording, :action)
  WidgetUsage = Data.define(:key, :view_variant, :title, :chart_type, :chart_options, :params, :blast_radius,
                            :link_to) do
    def effective_blast_radius(widget_definition)
      RecordingStudioAdmin::BlastRadius.max(widget_definition&.blast_radius, blast_radius)
    end
  end
  SectionWidgetUsage = WidgetUsage
  SECTION_WIDGET_VIEW_VARIANTS = %i[card compact].freeze
  SECTION_AVAILABILITY_SCOPES = %i[all root descendant].freeze
  DEFAULT_SECTION_AVAILABILITY_SCOPE = :root

  class Section < Definitions::Base
    class << self
      attr_reader :links_value, :widget_keys_value, :recordable_definition_value, :availability_scope_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@links_value, [])
        subclass.instance_variable_set(:@widget_keys_value, [])
        subclass.instance_variable_set(:@recordable_definition_value, nil)
        subclass.instance_variable_set(:@availability_scope_value, nil)
      end

      def link(name, text:, url:, style: :secondary, visible_if: nil)
        @links_value << Definitions::ButtonDefinition.new(name.to_sym, text, url, style, visible_if)
      end

      def widget(key, view_variant: nil, title: nil, chart_type: nil, chart_options: nil, params: nil,
                 blast_radius: nil, link_to: nil)
        normalized_view_variant = view_variant.nil? ? nil : normalize_view_variant(view_variant)
        normalized_blast_radius = if blast_radius.nil?
                                    nil
                                  else
                                    RecordingStudioAdmin::BlastRadius.normalize(
                                      blast_radius,
                                      owner: "Section widget #{key.inspect}"
                                    )
                                  end
        @widget_keys_value << WidgetUsage.new(
          key: key.to_s,
          view_variant: normalized_view_variant,
          title: title,
          chart_type: chart_type,
          chart_options: normalize_widget_usage_hash(chart_options, field_name: :chart_options),
          params: normalize_widget_usage_hash(params, field_name: :params),
          blast_radius: normalized_blast_radius,
          link_to: link_to
        )
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

      def availability_scope(value = nil, &block)
        @availability_scope_value = block || normalize_availability_scope(value) if value || block
        @availability_scope_value || DEFAULT_SECTION_AVAILABILITY_SCOPE
      end

      def links
        @links_value || []
      end

      def widget_keys
        widget_usages.map(&:key)
      end

      def widget_usages
        (@widget_keys_value || []).map do |entry|
          if entry.is_a?(WidgetUsage)
            entry
          else
            WidgetUsage.new(key: entry.to_s, view_variant: nil, title: nil, chart_type: nil,
                            chart_options: nil, params: nil, blast_radius: nil, link_to: nil)
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

    def self.normalize_widget_usage_hash(value, field_name:)
      return nil if value.nil? || value.respond_to?(:call)
      return value.to_h.deep_symbolize_keys if value.respond_to?(:to_h)

      raise InvalidDefinition, "Section widget #{field_name} must be a Hash"
    end

    def self.normalize_availability_scope(value)
      normalized = value.to_s.downcase.to_sym
      return normalized if SECTION_AVAILABILITY_SCOPES.include?(normalized)

      raise InvalidDefinition, "Section availability_scope has unsupported value #{value.inspect}"
    end
  end
end
