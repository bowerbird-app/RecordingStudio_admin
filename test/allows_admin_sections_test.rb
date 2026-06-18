# frozen_string_literal: true

require "test_helper"

class AllowsAdminSectionsTest < Minitest::Test
  class DslRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections do
      section :root
      section "stats"
      section nil
      section :root
    end
  end

  class ArityZeroRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections { %i[users jobs] }
  end

  class ArityOneRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections { |recordable| [recordable.class.name.demodulize.underscore] }
  end

  class ArityTwoRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections { |_recordable, recording| [recording.section_name] }
  end

  class ArityThreeRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections do |_recordable, _recording, context|
      [context.selected_section]
    end
  end

  class NilDefinitionRecordable
    include RecordingStudioAdmin::AllowsAdminSections
  end

  RecordingStub = Struct.new(:section_name)
  ContextStub = Struct.new(:selected_section)

  def test_dsl_definition_normalizes_keys
    keys = DslRecordable.recording_studio_admin_section_keys_for(
      DslRecordable.new,
      RecordingStub.new("ignored"),
      ContextStub.new("ignored")
    )

    assert_equal %w[root stats], keys
  end

  def test_callable_definition_with_arity_zero
    ArityZeroRecordable.instance_variable_set(
      :@recording_studio_admin_sections_definition,
      -> { %i[users jobs] }
    )

    keys = ArityZeroRecordable.recording_studio_admin_section_keys_for(
      ArityZeroRecordable.new,
      RecordingStub.new("ignored"),
      ContextStub.new("ignored")
    )

    assert_equal %w[users jobs], keys
  end

  def test_callable_definition_with_arity_one
    keys = ArityOneRecordable.recording_studio_admin_section_keys_for(
      ArityOneRecordable.new,
      RecordingStub.new("ignored"),
      ContextStub.new("ignored")
    )

    assert_equal ["arity_one_recordable"], keys
  end

  def test_callable_definition_with_arity_two
    keys = ArityTwoRecordable.recording_studio_admin_section_keys_for(
      ArityTwoRecordable.new,
      RecordingStub.new("operations"),
      ContextStub.new("ignored")
    )

    assert_equal ["operations"], keys
  end

  def test_callable_definition_with_arity_three
    keys = ArityThreeRecordable.recording_studio_admin_section_keys_for(
      ArityThreeRecordable.new,
      RecordingStub.new("ignored"),
      ContextStub.new("audits")
    )

    assert_equal ["audits"], keys
  end

  def test_returns_nil_when_definition_not_configured
    assert_nil NilDefinitionRecordable.recording_studio_admin_section_keys_for(
      NilDefinitionRecordable.new,
      RecordingStub.new("ignored"),
      ContextStub.new("ignored")
    )
  end

  def test_recording_studio_admin_sections_without_block_uses_empty_definition
    klass = Class.new do
      include RecordingStudioAdmin::AllowsAdminSections

      recording_studio_admin_sections
    end

    assert_equal [], klass.recording_studio_admin_section_keys_for(
      klass.new,
      RecordingStub.new("ignored"),
      ContextStub.new("ignored")
    )
  end
end