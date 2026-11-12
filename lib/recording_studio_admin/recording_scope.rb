# frozen_string_literal: true

module RecordingStudioAdmin
  module RecordingScope
    MODES = %w[self subtree].freeze
    MODE_CHOICES = [
      { value: "self", label: "Just here" }.freeze,
      { value: "subtree", label: "Everything under it" }.freeze
    ].freeze

    module_function

    def choice(params, allowed_types:, scope_key: :reach, type_key: :recordable_type)
      {
        mode: mode_from(read_param(params, scope_key)),
        recordable_type: type_from(read_param(params, type_key), allowed_types)
      }
    end

    def param_key(definition, type)
      filter = Array(definition&.filters).find { |entry| entry.type.to_sym == type.to_sym }
      return filter.param_key if filter

      type.to_sym == :scope ? :reach : type.to_sym
    end

    def mode_from(value)
      text = scalar_string(value)
      MODES.include?(text) ? text : "self"
    end

    def type_from(value, allowed_types)
      text = scalar_string(value)
      return if text.nil?

      text if Array(allowed_types).map(&:to_s).include?(text)
    end

    def read_param(params, key)
      return if params.nil?

      params[key].nil? ? params[key.to_s] : params[key]
    end

    def scalar_string(value)
      return if value.nil? || composite?(value)

      text = value.to_s
      text unless text.empty?
    end

    def composite?(value)
      value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(Numeric)
    end
  end
end
