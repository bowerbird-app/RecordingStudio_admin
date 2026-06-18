# frozen_string_literal: true

module RecordingStudioAdmin
  class Registry
    attr_reader :screens, :sections, :widgets, :resources

    def initialize
      @screens = {}
      @sections = {}
      @widgets = {}
      @resources = {}
    end

    def register_screen(klass)
      register(@screens, klass.key, klass)
      klass.widgets.each_value { |widget| register_widget(widget) }
      klass
    end

    def register_section(klass)
      register(@sections, klass.key, klass)
      klass
    end

    def register_widget(widget)
      register(@widgets, widget.key, widget)
      widget
    end

    def register_resource(klass)
      register(@resources, klass.key, klass)
      klass
    end

    def screen_for(key)
      @screens[key.to_s]
    end

    def section_for(key)
      @sections[key.to_s]
    end

    def widget_for(key)
      @widgets[key.to_s]
    end

    def resource_for(key)
      @resources[key.to_s]
    end

    def clear!
      @screens.clear
      @sections.clear
      @widgets.clear
      @resources.clear
    end

    private

    def register(store, key, value)
      normalized_key = key.to_s
      existing = store[normalized_key]
      return value if existing.equal?(value)
      return value if existing == value
      return store[normalized_key] = value if replaceable_reload?(existing, value)

      if existing
        raise RegistryConflict,
              "#{normalized_key.inspect} is already registered for #{definition_name(existing)}"
      end

      store[normalized_key] = value
    end

    def replaceable_reload?(existing, value)
      return false unless existing
      return true if reloadable_definition?(existing, value)

      reloadable_screen_widget?(existing, value)
    end

    def reloadable_definition?(existing, value)
      return false unless existing.respond_to?(:name) && value.respond_to?(:name)
      return false if existing.name.blank? || value.name.blank?

      existing.name == value.name
    end

    def reloadable_screen_widget?(existing, value)
      return false unless existing.is_a?(Widget) && value.is_a?(Widget)
      return false if existing.screen_key.blank? || value.screen_key.blank?

      existing.screen_key == value.screen_key && existing.local_key == value.local_key
    end

    def definition_name(definition)
      return definition.name if definition.respond_to?(:name) && definition.name

      definition.class.name
    end
  end
end
