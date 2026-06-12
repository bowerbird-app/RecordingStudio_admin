# frozen_string_literal: true

module RecordingStudioAdmin
  class Widget
    attr_reader :key, :local_key, :screen_key

    def initialize(local_key = nil, screen_key: nil, registry_prefix: nil, &block)
      @local_key = local_key&.to_s
      @screen_key = screen_key&.to_s
      @key = registry_prefix || [@screen_key, "widgets", @local_key].compact.join(".")
      @type = :stat
      instance_eval(&block) if block
    end

    %i[type title subtitle value change link_to series items rows metadata].each do |name|
      define_method(name) do |value = nil, &block|
        instance_variable_set("@#{name}", block || value) if value || block
        instance_variable_get("@#{name}")
      end
    end

    def resolve(context)
      Results::ResolvedWidget.new(
        key: key,
        type: evaluate(@type, context),
        title: evaluate(@title, context),
        subtitle: evaluate(@subtitle, context),
        value: evaluate(@value, context),
        change: evaluate(@change, context),
        link_to: evaluate(@link_to, context),
        series: evaluate(@series, context),
        items: evaluate(@items, context),
        rows: evaluate(@rows, context),
        metadata: evaluate(@metadata, context) || {}
      )
    end

    private

    def evaluate(value, context)
      value.respond_to?(:call) ? value.call(context) : value
    end
  end
end
