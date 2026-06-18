# frozen_string_literal: true

require "test_helper"

class RecordingStudioAdminApiTest < Minitest::Test
  class LinkedScreen < RecordingStudioAdmin::Screen
    key "linked_screen"
    title "Linked"
    query { |_context| [] }
  end

  class VisibleSection < RecordingStudioAdmin::Section
    key "visible"
    title "Visible"

    link :linked, text: "Linked", url: ->(context) { context.admin_screen_path("linked_screen") }
    link :hidden, text: "Hidden", url: ->(_context) { "/admin/screens/hidden" }, visible_if: ->(_context) { false }
  end

  class HiddenSection < RecordingStudioAdmin::Section
    key "hidden"
    title "Hidden"
    visible_if ->(_context) { false }

    link :linked, text: "Linked", url: ->(context) { context.admin_screen_path("linked_screen") }
  end

  RecordingStub = Struct.new(:recordable, :tag)

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    @original_admin_sections_resolver = RecordingStudioAdmin.configuration.admin_sections_resolver
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.configuration.admin_sections_resolver = nil
    RecordingStudioAdmin.register_screen(LinkedScreen)
    RecordingStudioAdmin.register_section(VisibleSection)
    RecordingStudioAdmin.register_section(HiddenSection)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
    RecordingStudioAdmin.configuration.admin_sections_resolver = @original_admin_sections_resolver
  end

  def test_configure_yields_configuration
    yielded = nil

    RecordingStudioAdmin.configure { |config| yielded = config }

    assert_same RecordingStudioAdmin.configuration, yielded
  end

  def test_available_sections_delegates_to_resolver
    context = RecordingStudioAdmin::Context.new

    with_singleton_stub(RecordingStudioAdmin::Resolvers::AvailableSectionsResolver, :call, ->(**kwargs) { kwargs }) do
      result = RecordingStudioAdmin.available_sections(context: context, placement: :root)

      assert_same context, result[:context]
      assert_equal :root, result[:placement]
    end
  end

  def test_section_enabled_returns_false_when_key_not_enabled
    RecordingStudioAdmin.configuration.admin_sections_resolver = -> { %w[visible] }
    context = RecordingStudioAdmin::Context.new

    enabled = RecordingStudioAdmin.section_enabled?(
      key: :hidden,
      recording: RecordingStub.new(nil, :tag),
      context: context
    )

    assert_equal false, enabled
  end

  def test_screen_enabled_uses_visible_enabled_sections_and_link_resolution
    RecordingStudioAdmin.configuration.admin_sections_resolver = -> { %w[visible hidden] }
    context = RecordingStudioAdmin::Context.new

    enabled = RecordingStudioAdmin.screen_enabled?(
      key: :linked_screen,
      recording: RecordingStub.new(nil, :tag),
      context: context
    )

    assert_equal true, enabled
  end

  def test_enabled_admin_section_keys_support_keyword_and_positional_resolvers
    context = RecordingStudioAdmin::Context.new
    recordable = Struct.new(:name).new("recordable")
    recording = RecordingStub.new(recordable, :reporting)

    RecordingStudioAdmin.configuration.admin_sections_resolver = lambda do |recording:, recordable:, context:|
      [recording.tag, recordable.name, context.class.name]
    end

    keys = RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)

    assert_equal ["reporting", "recordable", "RecordingStudioAdmin::Context"], keys

    RecordingStudioAdmin.configuration.admin_sections_resolver = ->(_recording) { [:one] }
    assert_equal ["one"], RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)

    RecordingStudioAdmin.configuration.admin_sections_resolver = ->(_recording, _context) { [:two] }
    assert_equal ["two"], RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)

    RecordingStudioAdmin.configuration.admin_sections_resolver = ->(_recording, _recordable, _context) { [:three] }
    assert_equal ["three"], RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)
  end
end