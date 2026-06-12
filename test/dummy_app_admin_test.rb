# frozen_string_literal: true

require "test_helper"

class DummyAppAdminTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_dummy_app_mounts_admin_and_accessible_engines
    routes = File.read(File.join(ROOT, "test/dummy/config/routes.rb"))

    assert_includes routes, 'mount RecordingStudioAccessible::Engine, at: "/admin/access"'
    assert_includes routes, 'mount RecordingStudioAdmin::Engine, at: "/admin"'
  end

  def test_dummy_app_registers_root_section_and_four_screens
    initializer = File.read(File.join(ROOT, "test/dummy/config/initializers/recording_studio_admin.rb"))

    assert_includes initializer, 'key "root"'
    assert_equal 4, initializer.scan("RecordingStudioAdmin.register_screen").size
    assert_includes initializer, 'widget "api_requests.widgets.activity_last_24_hours"'
    assert_includes initializer, 'widget "background_jobs.widgets.job_throughput"'
  end

  def test_dummy_seed_data_mentions_admin_demo
    seeds = File.read(File.join(ROOT, "test/dummy/db/seeds.rb"))

    assert_includes seeds, "ApiRequest"
    assert_includes seeds, "ApiError"
    assert_includes seeds, "UserActivity"
    assert_includes seeds, "BackgroundJobRun"
    assert_includes seeds, "RecordingStudio.root_recording_for(admin_root)"
  end
end
