# frozen_string_literal: true

module RecordingStudioAdmin
  class Widget
    VALID_TYPES = %i[number list chart].freeze
    LIST_OPTION_KEYS = %i[
      ordered
      spacing
      divider
      hover
      selectable
      orderable
      orderable_path
      orderable_method
      param_uuid_name
      param_target_position_name
    ].freeze
    LIST_ITEM_KEYS = %i[text label icon leading trailing href hover active link_arguments].freeze

    attr_reader :key, :local_key, :screen_key

    def initialize(local_key = nil, screen_key: nil, registry_prefix: nil, &block)
      @local_key = local_key&.to_s
      @screen_key = screen_key&.to_s
      @key = registry_prefix || [@screen_key, "widgets", @local_key].compact.join(".")
      @type = :number
      instance_eval(&block) if block
    end

    %i[type title subtitle description value change change_good_when link_to series chart_type chart_options
       list_options items rows metadata].each do |name|
      define_method(name) do |value = nil, &block|
        instance_variable_set("@#{name}", block || value) if value || block
        instance_variable_get("@#{name}")
      end
    end

    def resolve(context)
      attributes = resolved_attributes(context)

      validate!(**attributes.slice(:type, :value, :series, :chart_type, :items, :change_good_when))

      Results::ResolvedWidget.new(
        key: key,
        title: evaluate(@title, context),
        subtitle: evaluate(@subtitle, context),
        description: evaluate(@description, context),
        **attributes
      )
    end

    private

    def resolved_attributes(context)
      {
        type: normalize_type(evaluate(@type, context)),
        value: evaluate(@value, context),
        change: evaluate(@change, context),
        change_good_when: normalize_change_good_when(evaluate(@change_good_when, context)),
        link_to: RecordingStudioAdmin::UrlSafety.safe_href(evaluate(@link_to, context)),
        series: evaluate(@series, context),
        chart_type: evaluate(@chart_type, context),
        chart_options: evaluate(@chart_options, context) || {},
        list_options: normalize_list_options(evaluate(@list_options, context)),
        items: normalize_list_items(evaluate(@items, context)),
        rows: evaluate(@rows, context),
        metadata: evaluate(@metadata, context) || {},
        view_variant: nil
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

    def normalize_change_good_when(value)
      normalized = (value || :up).to_s.downcase.to_sym
      normalized = :up if normalized == :positive
      normalized = :down if normalized == :negative
      normalized
    end

    def validate!(type:, value:, series:, chart_type:, items:, change_good_when:)
      validate_type!(type)
      validate_change_good_when!(change_good_when)

      return validate_number_widget!(value) if type == :number
      return validate_list_widget!(items: items) if type == :list

      validate_chart_widget!(chart_type: chart_type, series: series)
    end

    def validate_type!(type)
      return if VALID_TYPES.include?(type)

      raise InvalidDefinition, "Widget #{key.inspect} has unsupported type #{type.inspect}"
    end

    def validate_change_good_when!(value)
      return if %i[up down neutral].include?(value)

      raise InvalidDefinition, "Widget #{key.inspect} has unsupported change_good_when #{value.inspect}"
    end

    def validate_number_widget!(value)
      return unless value.nil?

      raise InvalidDefinition, "Widget #{key.inspect} requires a value for type :number"
    end

    def validate_list_widget!(items:)
      return unless items.nil?

      raise InvalidDefinition, "Widget #{key.inspect} requires items for type :list"
    end

    def normalize_list_options(value)
      options = normalize_hash(value, field_name: :list_options)
      return {} if options.empty?

      unknown_keys = options.keys - LIST_OPTION_KEYS
      return options if unknown_keys.empty?

      raise InvalidDefinition, "Widget #{key.inspect} has unsupported list_options keys #{unknown_keys.inspect}"
    end

    def normalize_list_items(value)
      return nil if value.nil?

      collection = normalize_list_collection(value)
      collection.map { |item| normalize_list_item(item) }
    end

    def normalize_list_collection(value)
      return value.to_a if value.respond_to?(:to_a)

      raise InvalidDefinition, "Widget #{key.inspect} list items must be an array-like collection"
    end

    def normalize_list_item(item)
      return item unless item.is_a?(Hash)

      normalized = normalize_hash(item, field_name: :items)
      unknown_keys = normalized.keys - LIST_ITEM_KEYS
      unless unknown_keys.empty?
        raise InvalidDefinition, "Widget #{key.inspect} list item has unsupported keys #{unknown_keys.inspect}"
      end

      text = normalized[:text] || normalized[:label]
      raise InvalidDefinition, "Widget #{key.inspect} list item hashes require :text or :label" if text.nil?

      normalized[:href] = RecordingStudioAdmin::UrlSafety.safe_href(normalized[:href]) if normalized.key?(:href)
      normalized
    end

    def normalize_hash(value, field_name:)
      return {} if value.nil?
      return value.to_h.deep_symbolize_keys if value.respond_to?(:to_h)

      raise InvalidDefinition, "Widget #{key.inspect} #{field_name} must be a Hash"
    end

    def validate_chart_widget!(chart_type:, series:)
      raise InvalidDefinition, "Widget #{key.inspect} requires chart_type for type :chart" if chart_type.nil?
      raise InvalidDefinition, "Widget #{key.inspect} requires series for type :chart" if series.nil?
    end
  end
end
