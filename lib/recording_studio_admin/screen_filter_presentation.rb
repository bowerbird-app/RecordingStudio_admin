# frozen_string_literal: true

module RecordingStudioAdmin
  module ScreenFilterPresentation
    def filter_presentation(value = nil, inline_count: nil)
      if value.nil? && !inline_count.nil?
        raise InvalidDefinition, "Screen filter_presentation requires a presentation value"
      end

      assign_filter_presentation(value, inline_count) unless value.nil?
      @filter_presentation_value || :auto
    end

    def inline_filter_count
      @inline_filter_count_value || 0
    end

    def filter(name, type: nil, **options)
      key = name.to_sym
      existing = filters.find { |entry| entry.key == key }
      return merge_filter(existing, type, options) if existing

      resolved_type = (type || builtin_filter_type(key)).to_sym
      options[:param] ||= :reach if resolved_type == :scope
      @filters_value << Definitions::FilterDefinition.new(key, resolved_type, options)
    end

    private

    def assign_filter_presentation(value, inline_count)
      normalized_presentation = normalize_filter_presentation(value)
      normalized_inline_count = normalize_inline_filter_count(inline_count) unless inline_count.nil?

      if normalized_presentation == :inline && !normalized_inline_count.nil?
        raise InvalidDefinition, "Screen filter_presentation inline_count is only supported for modal filters"
      end

      @filter_presentation_value = normalized_presentation
      @inline_filter_count_value = normalized_inline_count unless inline_count.nil?
    end

    def normalize_filter_presentation(value)
      normalized = value.to_s.downcase.to_sym
      return normalized if %i[auto inline modal].include?(normalized)

      raise InvalidDefinition, "Screen filter_presentation has unsupported value #{value.inspect}"
    end

    def normalize_inline_filter_count(value)
      count = Integer(value)
      return count if count >= 0

      raise InvalidDefinition, "Screen filter_presentation inline_count must be a non-negative integer"
    rescue ArgumentError, TypeError
      raise InvalidDefinition, "Screen filter_presentation inline_count must be a non-negative integer"
    end

    def merge_filter(existing, type, options)
      if type && existing.type.to_sym != type.to_sym
        raise InvalidDefinition, "filter #{existing.key} is already #{existing.type}"
      end

      existing.options.merge!(options)
      existing
    end

    def builtin_filter_type(name)
      case name.to_sym
      when :date_range then :date_range
      when :group_by then :group_by
      else :select
      end
    end
  end
end
