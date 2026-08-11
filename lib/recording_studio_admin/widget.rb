# frozen_string_literal: true

module RecordingStudioAdmin
  class Widget
    VALID_TYPES = %i[number list chart progress].freeze
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
      compact_preview
    ].freeze
    LIST_ITEM_KEYS = %i[text label icon avatar leading trailing href hover active link_arguments].freeze
    COMPACT_LIST_PREVIEW_TYPES = %i[visual_stack text_summary].freeze

    attr_reader :key, :local_key, :source_location

    def initialize(local_key = nil, screen_key: nil, registry_prefix: nil, blast_radius: nil, &block)
      if screen_key
        raise InvalidDefinition,
              "Widgets must be standalone definitions. Pass an explicit widget key and register the widget separately."
      end

      @local_key = local_key&.to_s
      @key = registry_prefix || normalize_key(@local_key)
      @source_location = block&.source_location
      if blast_radius
        @blast_radius = RecordingStudioAdmin::BlastRadius.normalize(blast_radius,
                                                                    owner: "Widget #{key.inspect}")
      end
      @type = :number
      @show_metric = true
      @show_change = true
      @show_change_explicit = false
      @show_period = true
      instance_eval(&block) if block
    end

    %i[
      type title subtitle description info value change change_good_when link_to link_label series chart_type
      chart_options list_options items rows metadata
    ].each do |name|
      define_method(name) do |value = nil, &block|
        instance_variable_set("@#{name}", block || value) if value || block
        instance_variable_get("@#{name}")
      end
    end

    def blast_radius(value = nil)
      @blast_radius = RecordingStudioAdmin::BlastRadius.normalize(value, owner: "Widget #{key.inspect}") if value
      @blast_radius || RecordingStudioAdmin::BlastRadius::DEFAULT
    end

    def screen_key = nil

    def resolve(context)
      attributes = resolved_attributes(context)

      validate!(**attributes.slice(:type, :value, :series, :chart_type, :items, :change_good_when, :metadata))

      Results::ResolvedWidget.new(
        key: key,
        title: evaluate(@title, context),
        subtitle: evaluate(@subtitle, context),
        description: evaluate(@description, context),
        info: evaluate(@info, context),
        **attributes
      )
    end

    private

    def resolved_attributes(context)
      resolved_type = normalize_type(evaluate(@type, context))
      resolved_chart_type = evaluate(@chart_type, context)

      {
        type: resolved_type,
        value: evaluate(@value, context),
        change: evaluate(@change, context),
        change_good_when: normalize_change_good_when(evaluate(@change_good_when, context)),
        link_to: RecordingStudioAdmin::UrlSafety.safe_href(evaluate(@link_to, context)),
        link_label: resolve_link_label(context),
        series: evaluate(@series, context),
        chart_type: resolved_chart_type,
        chart_options: evaluate(@chart_options, context) || {},
        list_options: normalize_list_options(evaluate(@list_options, context)),
        items: normalize_list_items(evaluate(@items, context)),
        rows: evaluate(@rows, context),
        metadata: normalize_hash(evaluate(@metadata, context), field_name: :metadata),
        view_variant: nil,
        show_metric: @show_metric,
        show_change: resolved_show_change,
        show_period: @show_period
      }
    end

    def hide_metric = @show_metric = false

    def hide_change
      @show_change = false
      @show_change_explicit = true
    end

    def hide_period = @show_period = false

    def show_metric(value = true) = @show_metric = value

    def show_change(value = true)
      @show_change = value
      @show_change_explicit = true
    end

    def show_period(value = true) = @show_period = value

    def evaluate(value, context)
      value.respond_to?(:call) ? value.call(context) : value
    end

    def resolve_link_label(context)
      explicit_label = evaluate(@link_label, context)
      return explicit_label if explicit_label.present?

      nil
    end

    def normalize_key(value)
      raise InvalidDefinition, "Widget key is required" if value.blank?

      value.include?(".") ? value : "widgets.#{value}"
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

    def validate!(type:, value:, series:, chart_type:, items:, change_good_when:, metadata:)
      validate_type!(type)
      validate_change_good_when!(change_good_when)

      return validate_number_widget!(value) if type == :number
      return validate_list_widget!(items: items) if type == :list
      return validate_progress_widget!(metadata: metadata) if type == :progress

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

    def resolved_show_change
      @show_change
    end

    def validate_number_widget!(value)
      return unless value.nil?

      raise InvalidDefinition, "Widget #{key.inspect} requires a value for type :number"
    end

    def validate_list_widget!(items:)
      return unless items.nil?

      raise InvalidDefinition, "Widget #{key.inspect} requires items for type :list"
    end

    def validate_progress_widget!(metadata:)
      progress_value = metadata[:progress_value]
      progress_max = metadata.fetch(:progress_max, 100)
      return raise_missing_progress_value! if progress_value.nil?
      return raise_invalid_progress_value!("must be numeric") unless progress_value.is_a?(Numeric)
      return raise_invalid_progress_max!("must be numeric") unless progress_max.is_a?(Numeric)
      return raise_invalid_progress_value!("must be non-negative") if progress_value.negative?
      return raise_invalid_progress_max!("must be greater than zero") unless progress_max.positive?
      return if progress_value <= progress_max

      raise_invalid_progress_value!("must be less than or equal to progress_max")
    end

    def normalize_list_options(value)
      options = normalize_hash(value, field_name: :list_options)
      return {} if options.empty?

      unknown_keys = options.keys - LIST_OPTION_KEYS
      unless unknown_keys.empty?
        raise InvalidDefinition,
              "Widget #{key.inspect} has unsupported list_options keys #{unknown_keys.inspect}"
      end

      normalize_compact_list_preview!(options)
      options
    end

    def normalize_compact_list_preview!(options)
      return unless options.key?(:compact_preview)

      compact_preview = options[:compact_preview].to_s.downcase.to_sym
      unless COMPACT_LIST_PREVIEW_TYPES.include?(compact_preview)
        raise InvalidDefinition,
              "Widget #{key.inspect} has unsupported compact_preview #{options[:compact_preview].inspect}"
      end

      options[:compact_preview] = compact_preview
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

    def raise_missing_progress_value!
      raise InvalidDefinition, "Widget #{key.inspect} requires metadata[:progress_value] for type :progress"
    end

    def raise_invalid_progress_value!(message)
      raise InvalidDefinition, "Widget #{key.inspect} metadata[:progress_value] #{message}"
    end

    def raise_invalid_progress_max!(message)
      raise InvalidDefinition, "Widget #{key.inspect} metadata[:progress_max] #{message}"
    end
  end
end
