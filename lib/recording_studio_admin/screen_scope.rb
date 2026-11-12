# frozen_string_literal: true

module RecordingStudioAdmin
  module ScreenScope
    def scopeable(recordable_types:)
      @scopeable_recordable_types = normalize_scopeable_types(recordable_types).freeze
      ensure_scope_filter(:scope, :scope, values: RecordingScope::MODE_CHOICES)
      ensure_scope_filter(:recordable_type, :recordable_type, values: @scopeable_recordable_types)
      @scopeable_recordable_types
    end

    def scopeable_recordable_types
      @scopeable_recordable_types
    end

    def scopeable?
      Array(scopeable_recordable_types).any?
    end

    private

    def ensure_scope_filter(name, type, **)
      existing = filters.find { |entry| entry.key == name }
      return raise_scope_filter_conflict(existing, type) if existing && existing.type.to_sym != type
      return existing if existing

      filter(name, type: type, **)
    end

    def raise_scope_filter_conflict(existing, type)
      raise InvalidDefinition, "filter #{existing.key} is already #{existing.type}, not #{type}"
    end

    def normalize_scopeable_types(recordable_types)
      types = Array(recordable_types).filter_map { |type| scopeable_type_name(type) }.uniq
      raise InvalidDefinition, "scopeable recordable_types needs at least one recordable class" if types.empty?

      types.each { |type| validate_scopeable_type!(type) }
      types
    end

    def scopeable_type_name(type)
      name = type.respond_to?(:name) && !type.is_a?(String) ? type.name : type.to_s
      name.to_s.strip.presence
    end

    def validate_scopeable_type!(type)
      return if type.match?(/\A[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*\z/)

      raise InvalidDefinition, "scopeable recordable_types includes #{type.inspect}"
    end
  end
end
