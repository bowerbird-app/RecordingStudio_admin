# frozen_string_literal: true

require "test_helper"

class SectionRecordingResolverTrashableParityTest < Minitest::Test
  class RecordingRow
    attr_reader :id, :trashed_at, :root_recording, :parent_recording, :recordable

    def initialize(id:, trashed_at:, root_recording:, parent_recording:, recordable:)
      @id = id
      @trashed_at = trashed_at
      @root_recording = root_recording
      @parent_recording = parent_recording
      @recordable = recordable
    end
  end

  class FakeRelation
    attr_reader :filters, :unscoped_called, :kept_called

    def initialize(rows)
      @rows = rows
      @filters = {}
      @unscoped_called = false
      @kept_called = false
    end

    def unscoped
      @unscoped_called = true
      self
    end

    def kept
      @kept_called = true
      @filters[:trashed_at] = nil
      self
    end

    def find_by(attributes)
      @filters.merge!(attributes)
      @rows.find do |row|
        @filters.all? do |key, expected|
          actual = row.public_send(key)
          expected.nil? && key == :trashed_at ? actual.nil? : actual == expected
        end
      end
    end
  end

  class FakeRecordingModel
    class << self
      attr_accessor :relation

      def unscoped
        relation.unscoped
      end
    end
  end

  def setup
    @root = Object.new
    @parent = Object.new
    @recordable = Object.new
    @kept = RecordingRow.new(
      id: 1,
      trashed_at: nil,
      root_recording: @root,
      parent_recording: @parent,
      recordable: @recordable
    )
    @trashed = RecordingRow.new(
      id: 2,
      trashed_at: Time.utc(2026, 1, 1),
      root_recording: @root,
      parent_recording: @parent,
      recordable: @recordable
    )
    @relation = FakeRelation.new([@kept, @trashed])
    FakeRecordingModel.relation = @relation
  end

  def test_find_recording_uses_unscoped_kept
    found = with_fake_recording_model do
      resolver.send(:find_recording, @recordable, @root, @parent)
    end

    assert_equal @kept, found
    assert @relation.unscoped_called
    assert @relation.kept_called
  end

  def test_find_recording_skips_trashed_rows
    found = with_fake_recording_model do
      resolver.send(:find_recording, @recordable, @root, @parent)
    end

    assert_equal @kept.id, found.id
    refute_equal @trashed.id, found.id
  end

  def test_engine_requires_query_only_not_full_trashable
    engine = File.read(File.expand_path("../lib/recording_studio_admin/engine.rb", __dir__))

    assert_includes engine, 'require "recording_studio_trashable/query"'
    refute_includes engine, 'require "recording_studio_trashable" if defined?(Bundler)'
  end

  def test_dependencies_pin_core_6_14_and_trashable_0_16
    root = File.expand_path("..", __dir__)
    gemspec = File.read(File.join(root, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(root, "Gemfile"))
    dummy_gemfile = File.read(File.join(root, "test/dummy/Gemfile"))

    assert_includes gemspec, 'recording_studio", ">= 6.14.0", "< 7"'
    assert_includes gemspec, 'recording_studio_trashable", ">= 0.16.0", "< 1"'
    assert_includes gemfile, 'tag: "v6.14.0"'
    assert_includes gemfile, 'tag: "v0.16.0"'
    assert_includes gemfile, "require: false"
    assert_includes dummy_gemfile, 'tag: "v6.14.0"'
    assert_includes dummy_gemfile, 'tag: "v0.16.0"'
    assert_includes dummy_gemfile, "require: false"
  end

  private

  def resolver
    RecordingStudioAdmin::SectionRecordingResolver.allocate
  end

  def with_fake_recording_model
    created_recording_studio = false
    unless defined?(RecordingStudio)
      Object.const_set(:RecordingStudio, Module.new)
      created_recording_studio = true
    end

    recording_studio = Object.const_get(:RecordingStudio)
    had_recording = recording_studio.const_defined?(:Recording, false)
    original = recording_studio.const_get(:Recording) if had_recording
    recording_studio.send(:remove_const, :Recording) if had_recording
    recording_studio.const_set(:Recording, FakeRecordingModel)

    yield
  ensure
    if defined?(recording_studio) && recording_studio.const_defined?(:Recording, false)
      recording_studio.send(:remove_const, :Recording)
      recording_studio.const_set(:Recording, original) if had_recording
    end
    Object.send(:remove_const, :RecordingStudio) if created_recording_studio
  end
end
