# frozen_string_literal: true

require "test_helper"

class DummyAppAdminTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_dummy_app_mounts_admin_and_accessible_engines
    routes = File.read(File.join(ROOT, "test/dummy/config/routes.rb"))

    assert_includes routes, 'mount RecordingStudioAccessible::Engine, at: "/admin/access"'
    assert_includes routes, 'mount RecordingStudioAdmin::Engine, at: "/admin"'
  end

  def test_dummy_app_registers_demo_sections_and_user_focused_screens
    initializer = File.read(File.join(ROOT, "test/dummy/config/initializers/recording_studio_admin.rb"))

    assert_includes initializer, 'key "root"'
    assert_includes initializer, 'key "users"'
    assert_equal 8, initializer.scan("RecordingStudioAdmin.register_screen").size
    assert_equal 2, initializer.scan("RecordingStudioAdmin.register_section").size
    assert_includes initializer, 'widget "api_requests.widgets.api_activity",'
    assert_includes initializer, "view_variant: :compact"
    assert_includes initializer, 'widget "most_common_errors.widgets.error_distribution_chart"'
    assert_includes initializer, 'widget "background_jobs.widgets.job_throughput"'
    assert_includes initializer, "RecordingStudioAdmin.register_screen(AdminScreens::UserSignIns)"
    assert_includes initializer, "RecordingStudioAdmin.register_screen(AdminScreens::UserReviews)"
    assert_includes initializer, "RecordingStudioAdmin.register_screen(AdminScreens::UserInvitations)"
    assert_includes initializer, 'widget "user_sign_ins.widgets.sign_in_activity",'
    assert_includes initializer, 'widget "user_reviews.widgets.review_volume",'
    assert_includes initializer, 'widget "user_invitations.widgets.recent_invites"'
    assert_includes initializer, 'navigation_parent "root"'
    assert_includes initializer, 'navigation_parent "users"'
  end

  def test_dummy_app_includes_admin_root_live_search_controller
    controller = File.read(File.join(ROOT, "test/dummy/app/javascript/controllers/admin/root_search_controller.js"))

    assert_includes controller, 'static targets = ["input", "results", "emptyState", "item"]'
    assert_includes controller, "const matches = query.length > 0 && searchText.includes(query)"
    assert_includes controller, "this.emptyStateTarget.hidden = query.length === 0 || visibleCount > 0"
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
