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

  def test_register_section
    @registry.register_section(RootSection)

    assert_equal RootSection, @registry.section_for(:root)
  end
end
