# frozen_string_literal: true

require "test_helper"

class RegistryTest < Minitest::Test
  class ExampleScreen < RecordingStudioAdmin::Screen
    key "example"
    widget :summary do
      title "Summary"
      value { 1 }
    end
  end

  class DuplicateScreen < RecordingStudioAdmin::Screen
    key "example"
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    widget "example.widgets.summary"
  end

  class DuplicateSection < RecordingStudioAdmin::Section
    key "root"
  end

  def setup
    @registry = RecordingStudioAdmin::Registry.new
  end

  def test_register_screen_is_idempotent_and_registers_namespaced_widgets
    @registry.register_screen(ExampleScreen)
    @registry.register_screen(ExampleScreen)

    assert_equal ExampleScreen, @registry.screen_for("example")
    assert @registry.widget_for("example.widgets.summary")
    assert_equal 1, @registry.screens.size
  end

  def test_register_screen_conflict_raises
    @registry.register_screen(ExampleScreen)

    assert_raises(RecordingStudioAdmin::RegistryConflict) do
      @registry.register_screen(DuplicateScreen)
    end
  end

  def test_register_screen_replaces_reloaded_definition_with_same_name
    reloaded_screen = Class.new(RecordingStudioAdmin::Screen) do
      key "example"
      widget :summary do
        title "Reloaded summary"
        value { 2 }
      end
    end
    reloaded_screen.define_singleton_method(:name) { "RegistryTest::ExampleScreen" }

    @registry.register_screen(ExampleScreen)
    @registry.register_screen(reloaded_screen)

    assert_equal reloaded_screen, @registry.screen_for("example")
    assert_equal reloaded_screen.widgets.fetch("example.widgets.summary"),
                 @registry.widget_for("example.widgets.summary")
  end

  def test_register_section
    @registry.register_section(RootSection)

    assert_equal RootSection, @registry.section_for(:root)
  end

  def test_register_section_conflict_raises
    @registry.register_section(RootSection)

    assert_raises(RecordingStudioAdmin::RegistryConflict) do
      @registry.register_section(DuplicateSection)
    end
  end

  def test_register_section_replaces_reloaded_definition_with_same_name
    reloaded_section = Class.new(RecordingStudioAdmin::Section) do
      key "root"
    end
    reloaded_section.define_singleton_method(:name) { "RegistryTest::RootSection" }

    @registry.register_section(RootSection)
    @registry.register_section(reloaded_section)

    assert_equal reloaded_section, @registry.section_for("root")
  end

  def test_register_widget_conflict_raises_registry_conflict
    first = RecordingStudioAdmin::Widget.new("system_health") { title "System health" }
    second = RecordingStudioAdmin::Widget.new("system_health") { title "Other health" }
    @registry.register_widget(first)

    error = assert_raises(RecordingStudioAdmin::RegistryConflict) do
      @registry.register_widget(second)
    end
    assert_includes error.message, "widgets.system_health"
  end

  def test_clear_resets_all_registries
    @registry.register_screen(ExampleScreen)
    @registry.register_section(RootSection)

    @registry.clear!

    assert_empty @registry.screens
    assert_empty @registry.sections
    assert_empty @registry.widgets
  end
end
