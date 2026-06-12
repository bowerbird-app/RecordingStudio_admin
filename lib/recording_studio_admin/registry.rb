# frozen_string_literal: true

module RecordingStudioAdmin
  class Registry
    attr_reader :screens, :sections, :widgets

    def initialize
      @screens = {}
      @sections = {}
      @widgets = {}
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

    def screen_for(key)
      @screens[key.to_s]
    end

    def section_for(key)
      @sections[key.to_s]
    end

    def widget_for(key)
      @widgets[key.to_s]
    end

    def clear!
      @screens.clear
      @sections.clear
      @widgets.clear
    end

    private

    def register(store, key, value)
      normalized_key = key.to_s
      existing = store[normalized_key]
      return value if existing.equal?(value)
      return value if existing == value

      if existing
        raise RegistryConflict, "#{normalized_key.inspect} is already registered for #{existing.name || existing.class.name}"
      end

      store[normalized_key] = value
    end
  end
end
