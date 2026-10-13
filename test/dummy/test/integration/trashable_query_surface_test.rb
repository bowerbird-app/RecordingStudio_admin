# frozen_string_literal: true

require "test_helper"

# Admin pins Trashable with require: false and loads query-only helpers.
# The full engine must not appear in the dummy host surface.
class TrashableQuerySurfaceTest < ActionDispatch::IntegrationTest
  test "query-only load does not boot Trashable engine side effects" do
    assert defined?(RecordingStudioTrashable), "query helpers module should load"
    assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_kept_sql)
    assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_active)

    refute defined?(RecordingStudioTrashable::Engine),
           "full Trashable engine must not load via Admin query-only require"

    engines = Rails::Engine.subclasses.map(&:name)
    refute_includes engines, "RecordingStudioTrashable::Engine"

    pins = Rails.application.importmap.packages.keys.map(&:to_s)
    refute_includes pins, "controllers/recording_studio_trashable/live_search_controller"

    tags = ApplicationController.helpers.javascript_importmap_tags.to_s
    refute_includes tags, "recording_studio_trashable/live_search_controller"
    refute_includes tags, 'modulepreload" href="/recording_studio_trashable/'

    caps = RecordingStudio.registered_capabilities
    refute caps.key?(:trashable), "query-only must not register :trashable capability"
    refute caps.key?("trashable")

    recording = RecordingStudio::Recording
    refute recording.instance_methods.include?(:recording_studio_trashable_trash!)
    refute recording.instance_methods.include?(:recording_studio_trashable_restore!)
    refute recording.instance_methods.include?(:recording_studio_trashable_purge!)

    refute defined?(RecordingStudioTrashable::CopyHelper)

    if defined?(RecordingStudioMetrics) && RecordingStudioMetrics.respond_to?(:registry)
      registry = RecordingStudioMetrics.registry
      names =
        if registry.respond_to?(:keys)
          registry.keys.map(&:to_s)
        elsif registry.respond_to?(:resources)
          Array(registry.resources).map(&:to_s)
        else
          registry.inspect
        end
      refute_match(/\btrash\b/, names.to_s)
    end
  end
end
