# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_defaults
    config = RecordingStudioAdmin::Configuration.new

    assert_equal "/admin", config.default_mount_path
    assert_nil config.layout
    assert_equal :authenticate_user!, config.authentication_method
    assert_equal :current_user, config.current_actor_method
    assert_equal :recording_studio_admin_access_recording, config.access_recording_method
    assert_nil config.access_recording_resolver
    assert_nil config.current_root_recording_resolver
    assert_nil config.site_admin_recording_resolver
    assert_equal :view, config.required_access_role
    assert_equal 1_000, config.max_page
    assert_equal true, config.async_widgets.enabled
    assert_equal 4, config.async_widgets.max_concurrent_requests
    assert_equal 1, config.async_widgets.retry_count
    assert_equal :indefinite, config.logs_retention
    assert_equal "AdminAuditLog", config.audit_log_model
    assert_empty config.surfaces
  end

  def test_logs_retention_defaults_to_indefinite_and_merges
    config = RecordingStudioAdmin::Configuration.new

    assert_equal :indefinite, config.logs_retention

    config.merge!(logs_retention: 90.days)

    assert_equal 90.days, config.logs_retention
  end

  def test_merge_updates_known_keys_only
    config = RecordingStudioAdmin::Configuration.new

    config.merge!("default_mount_path" => "/backoffice", "layout" => "flat_pack_sidebar", "unknown" => true)

    assert_equal "/backoffice", config.default_mount_path
    assert_equal "flat_pack_sidebar", config.layout
  end

  def test_merge_updates_async_widget_configuration
    config = RecordingStudioAdmin::Configuration.new

    config.merge!("async_widgets" => {
                    "enabled" => true,
                    "max_concurrent_requests" => 2,
                    "retry_count" => 0,
                    "unknown" => true
                  })

    assert_equal true, config.async_widgets.enabled
    assert_equal 2, config.async_widgets.max_concurrent_requests
    assert_equal 0, config.async_widgets.retry_count
  end

  def test_surface_configures_named_entrypoint
    config = RecordingStudioAdmin::Configuration.new
    resolver = ->(_context) { :recording }

    surface = config.surface(:stats, path: "/stats", root_section: :page_views) do |configured_surface|
      configured_surface.authentication_method = :authenticate_user!
      configured_surface.access_recording_resolver = resolver
    end

    assert_same surface, config.surface_for(:stats)
    assert_equal "stats", surface.key
    assert_equal "/stats", surface.path
    assert_equal "page_views", surface.root_section
    assert_equal :authenticate_user!, surface.authentication_method
    assert_same resolver, surface.access_recording_resolver
  end

  def test_surface_for_request_uses_longest_matching_mount_path
    config = RecordingStudioAdmin::Configuration.new
    admin = config.surface(:admin, path: "/admin")
    stats = config.surface(:stats, path: "/admin/stats")
    request = Struct.new(:path, :script_name).new("/admin/stats/sections/page_views", "")

    assert_same stats, config.surface_for_request(request)

    request.path = "/admin/sections/root"

    assert_same admin, config.surface_for_request(request)
  end

  def test_default_surface_reflects_global_configuration
    config = RecordingStudioAdmin::Configuration.new
    config.default_mount_path = "/backoffice"
    config.layout = "admin"

    surface = config.default_surface

    assert_equal "default", surface.key
    assert_equal "/backoffice", surface.path
    assert_equal "root", surface.root_section
    assert_equal "admin", surface.layout
    assert_equal "admin", config.layout_for(surface)
  end

  def test_current_root_recording_resolver_prefers_surface_then_global
    config = RecordingStudioAdmin::Configuration.new
    global_resolver = ->(_context) { :global_root }
    surface_resolver = ->(_context) {}
    config.current_root_recording_resolver = global_resolver

    assert_same global_resolver, config.current_root_recording_resolver_for(nil)
    assert_same global_resolver, config.default_surface.current_root_recording_resolver

    surface = config.surface(:stats, path: "/stats", current_root_recording_resolver: surface_resolver)

    assert_same surface_resolver, config.current_root_recording_resolver_for(surface)
    assert_same global_resolver, config.current_root_recording_resolver_for(config.surface(:other, path: "/other"))
  end

  def test_layout_accepts_nil_false_string_and_keyword_callable
    config = RecordingStudioAdmin::Configuration.new

    config.layout = nil
    assert_nil config.layout

    config.layout = false
    assert_equal false, config.layout

    config.layout = "admin_pages"
    assert_equal "admin_pages", config.layout

    callable = ->(controller:) { controller.class.name }
    config.layout = callable
    assert_same callable, config.layout
  end

  def test_invalid_layout_values_raise_argument_error
    config = RecordingStudioAdmin::Configuration.new

    assert_raises(ArgumentError) { config.layout = "" }
    assert_raises(ArgumentError) { config.layout = 1 }
    assert_raises(ArgumentError) { config.layout = ->(_) { "pages" } }
    assert_raises(ArgumentError) { config.layout = -> { "pages" } }
  end

  def test_named_surface_layout_overrides_the_gem_layout
    config = RecordingStudioAdmin::Configuration.new
    config.layout = "admin_pages"
    surface = config.surface(:stats, path: "/stats", layout: "stats_pages")

    assert_equal "stats_pages", config.layout_for(surface)
    assert_equal "admin_pages", config.layout_for(config.surface(:reports, path: "/reports"))
  end

  def test_false_surface_layout_does_not_fall_through
    config = RecordingStudioAdmin::Configuration.new
    config.layout = "admin_pages"
    surface = config.surface(:bare, path: "/bare", layout: false)

    assert_equal false, config.layout_for(surface)
  end
end
