# frozen_string_literal: true

module RecordingStudioAdmin
  module ScreenScope
    def scopeable(recordable_types:)
      @scopeable_recordable_types = normalize_scopeable_types(recordable_types).freeze
      ensure_scope_filter(:recordable_type, :recordable_type, values: @scopeable_recordable_types)
      recheck_within_filters!
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

    def recheck_within_filters!
      filters.each do |entry|
        next unless entry.type.to_sym == :within

        type_name = entry.options[:recordable_type].to_s
        next if scopeable_recordable_types.include?(type_name)

        raise InvalidDefinition, "filter #{entry.key} recordable_type #{type_name.inspect} is not scopeable"
      end
    end

    def validate_within_filter!(key, options)
      options[:recordable_type] = validated_within_type(key, options[:recordable_type])
      reject_reserved_within_param!(key, options)
    end

    def validated_within_type(key, raw)
      type_name = scopeable_type_name(raw)
      raise InvalidDefinition, "filter #{key} needs recordable_type" if type_name.nil?

      validate_scopeable_type!(type_name)
      return type_name if !scopeable? || scopeable_recordable_types.include?(type_name)

      raise InvalidDefinition, "filter #{key} recordable_type #{type_name.inspect} is not scopeable"
    end

    def reject_reserved_within_param!(key, options)
      param = (options[:param] || key).to_sym
      return unless %i[scope reach].include?(param)

      raise InvalidDefinition, "filter #{key} cannot use param #{param}"
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
