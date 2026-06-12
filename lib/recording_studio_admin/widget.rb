# frozen_string_literal: true

module RecordingStudioAdmin
  class Widget
    VALID_TYPES = %i[number list chart].freeze

    attr_reader :key, :local_key, :screen_key

    def initialize(local_key = nil, screen_key: nil, registry_prefix: nil, &block)
      @local_key = local_key&.to_s
      @screen_key = screen_key&.to_s
      @key = registry_prefix || [@screen_key, "widgets", @local_key].compact.join(".")
      @type = :number
      instance_eval(&block) if block
    end

    %i[type title subtitle value change link_to series chart_type chart_options items rows metadata].each do |name|
      define_method(name) do |value = nil, &block|
        instance_variable_set("@#{name}", block || value) if value || block
        instance_variable_get("@#{name}")
      end
    end

    def resolve(context)
      attributes = resolved_attributes(context)

      validate!(**attributes.slice(:type, :value, :series, :chart_type, :items))

      Results::ResolvedWidget.new(
        key: key,
        title: evaluate(@title, context),
        subtitle: evaluate(@subtitle, context),
        **attributes
      )
    end

    private

    def resolved_attributes(context)
      {
        type: normalize_type(evaluate(@type, context)),
        value: evaluate(@value, context),
        change: evaluate(@change, context),
        link_to: RecordingStudioAdmin::UrlSafety.safe_href(evaluate(@link_to, context)),
        series: evaluate(@series, context),
        chart_type: evaluate(@chart_type, context),
        chart_options: evaluate(@chart_options, context) || {},
        items: evaluate(@items, context),
        rows: evaluate(@rows, context),
        metadata: evaluate(@metadata, context) || {}
      }
    end

    def evaluate(value, context)
      value.respond_to?(:call) ? value.call(context) : value
    end

    def normalize_type(value)
      normalized = value.to_s.downcase.to_sym
      normalized = :number if normalized == :stat
      normalized
    end

    def validate!(type:, value:, series:, chart_type:, items:)
      validate_type!(type)

      return validate_number_widget!(value) if type == :number
      return validate_list_widget!(items) if type == :list

      validate_chart_widget!(chart_type: chart_type, series: series)
    end

    def validate_type!(type)
      return if VALID_TYPES.include?(type)

      raise InvalidDefinition, "Widget #{key.inspect} has unsupported type #{type.inspect}"
    end

    def validate_number_widget!(value)
      return unless value.nil?

      raise InvalidDefinition, "Widget #{key.inspect} requires a value for type :number"
    end

    def validate_list_widget!(items)
      return unless items.nil?

      raise InvalidDefinition, "Widget #{key.inspect} requires items for type :list"
    end

    def validate_chart_widget!(chart_type:, series:)
      raise InvalidDefinition, "Widget #{key.inspect} requires chart_type for type :chart" if chart_type.nil?
      raise InvalidDefinition, "Widget #{key.inspect} requires series for type :chart" if series.nil?
    end
  end
end
