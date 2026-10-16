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
    attr_reader :filters, :unscoped_called, :kept_sql_called, :active_called

    def initialize(rows)
      @rows = rows
      @filters = {}
      @unscoped_called = false
      @kept_sql_called = false
      @active_called = false
    end

    def unscoped
      @unscoped_called = true
      self
    end

    def recording_studio_trashable_active
      @active_called = true
      @filters[:trashed_at] = nil
      self
    end

    def where(condition = nil, *)
      if condition.is_a?(String) && condition.include?("trashed_at")
        @kept_sql_called = true
        @filters[:trashed_at] = nil
      elsif condition.is_a?(Hash)
        @filters.merge!(condition)
      end
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
      attr_accessor :relation, :column_names, :respond_to_kept_sql

      def unscoped
        relation.unscoped
      end

      def where(...)
        relation.where(...)
      end

      def recording_studio_trashable_kept_sql(table = "recording_studio_recordings")
        %("#{table}"."trashed_at" IS NULL)
      end

      def respond_to?(method_name, include_all = false) # rubocop:disable Style/OptionalBooleanParameter
        return respond_to_kept_sql if method_name == :recording_studio_trashable_kept_sql

        super
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
    FakeRecordingModel.column_names = %w[id trashed_at]
    FakeRecordingModel.respond_to_kept_sql = true
  end

  def test_find_recording_uses_kept_sql_on_main_unscoped_base
    found = with_fake_recording_model do
      resolver.send(:find_recording, @recordable, @root, @parent)
    end

    assert_equal @kept, found
    assert @relation.unscoped_called, "SectionRecordingResolver must keep main's unscoped base"
    assert @relation.kept_sql_called
    refute @relation.active_called, "must not use recording_studio_trashable_active"
    assert_nil @relation.filters[:trashed_at]
  end

  def test_find_recording_skips_trashed_rows_like_main
    found = with_fake_recording_model do
      resolver.send(:find_recording, @recordable, @root, @parent)
    end

    assert_equal @kept.id, found.id
    refute_equal @trashed.id, found.id
  end

  def test_find_recording_falls_back_without_kept_sql_helper
    FakeRecordingModel.respond_to_kept_sql = false

    found = with_fake_recording_model do
      resolver.send(:find_recording, @recordable, @root, @parent)
    end

    assert_equal @kept, found
    assert @relation.unscoped_called
    refute @relation.kept_sql_called
    assert_nil @relation.filters[:trashed_at]
  end

  def test_kept_sql_available_requires_helper_and_column
    with_fake_recording_model do
      assert resolver.send(:kept_sql_available?)

      FakeRecordingModel.respond_to_kept_sql = false
      refute resolver.send(:kept_sql_available?)

      FakeRecordingModel.respond_to_kept_sql = true
      FakeRecordingModel.column_names = %w[id]
      refute resolver.send(:kept_sql_available?)
    end
  end

  def test_engine_requires_query_only_not_full_trashable
    engine = File.read(File.expand_path("../lib/recording_studio_admin/engine.rb", __dir__))

    assert_includes engine, 'require "recording_studio_trashable/query"'
    refute_includes engine, 'require "recording_studio_trashable" if defined?(Bundler)'
  end

  def test_dependencies_pin_trashable_v0_10_0_require_false
    root = File.expand_path("..", __dir__)
    gemspec = File.read(File.join(root, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(root, "Gemfile"))
    dummy_gemfile = File.read(File.join(root, "test/dummy/Gemfile"))

    assert_includes gemspec, 'recording_studio_trashable", "~> 0.10"'
    assert_includes gemfile, 'tag: "v0.11.0"'
    assert_includes gemfile, "require: false"
    assert_includes dummy_gemfile, 'tag: "v0.11.0"'
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
