# frozen_string_literal: true

require "test_helper"

class DummyAppAdminTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_dummy_app_mounts_admin_and_accessible_engines
    routes = File.read(File.join(ROOT, "test/dummy/config/routes.rb"))

    assert_includes routes, 'mount RecordingStudioAccessible::Engine, at: "/admin/access"'
    assert_includes routes, 'recording_studio_admin_for :admin, at: "/admin", root_section: :root'
  end

  def test_dummy_app_registers_demo_sections_and_user_focused_screens
    initializer = File.read(File.join(ROOT, "test/dummy/config/initializers/recording_studio_admin.rb"))
    root_section = File.read(File.join(ROOT, "test/dummy/app/admin/root/section.rb"))
    api_section = File.read(File.join(ROOT, "test/dummy/app/admin/api/section.rb"))
    users_section = File.read(File.join(ROOT, "test/dummy/app/admin/users/section.rb"))
    jobs_section = File.read(File.join(ROOT, "test/dummy/app/admin/jobs/section.rb"))
    admin_root = File.read(File.join(ROOT, "test/dummy/app/models/admin_root.rb"))
    manifest = File.read(File.join(ROOT, "test/dummy/app/admin/manifest.rb"))
    users_manifest = File.read(File.join(ROOT, "test/dummy/app/admin/users/manifest.rb"))
    api_manifest = File.read(File.join(ROOT, "test/dummy/app/admin/api/manifest.rb"))
    jobs_manifest = File.read(File.join(ROOT, "test/dummy/app/admin/jobs/manifest.rb"))
    root_manifest = File.read(File.join(ROOT, "test/dummy/app/admin/root/manifest.rb"))
    screen_files = Dir[File.join(ROOT, "test/dummy/app/admin/**/screen.rb")]
    chart_files = Dir[File.join(ROOT, "test/dummy/app/admin/**/chart.rb")]
    table_files = Dir[File.join(ROOT, "test/dummy/app/admin/**/table.rb")]
    widget_files = Dir[File.join(ROOT, "test/dummy/app/admin/**/widgets/*.rb")]
    api_requests_chart = File.read(File.join(ROOT, "test/dummy/app/admin/api/api_requests/chart.rb"))
    api_requests_table = File.read(File.join(ROOT, "test/dummy/app/admin/api/api_requests/table.rb"))
    api_activity_widget = File.read(File.join(ROOT, "test/dummy/app/admin/api/api_requests/widgets/api_activity.rb"))
    review_volume_widget = File.read(File.join(ROOT, "test/dummy/app/admin/users/user_reviews/widgets/review_volume.rb"))

    assert_includes initializer, "AdminScreens.load!"
    assert_includes initializer, "AdminScreens::Root.register!"
    assert_includes initializer, "AdminScreens::Api.register!"
    assert_includes initializer, "AdminScreens::UsersArea.register!"
    refute_includes initializer, "AdminScreens::AdminActivityLogsArea.register!"
    assert_includes initializer, "AdminScreens::Stats.register!"
    assert_includes initializer, "config.admin_action_auditor = lambda do |event|"
    assert_includes api_section, 'key "api"'
    assert_includes users_section, 'key "users"'
    assert_includes jobs_section, 'key "jobs"'
    assert_includes admin_root, "section :api"
    assert_includes admin_root, "section :admin_activity_logs"
    assert_includes admin_root, "section :jobs"
    refute_includes manifest, "admin_activity_logs/admin_activity_logs/screen"
    refute_includes manifest, "AdminActivityLogsScreen"
    assert_equal 11, screen_files.size
    assert_equal 11, chart_files.size
    assert_equal 11, table_files.size
    assert_equal 19, widget_files.size
    assert_empty screen_files.select { |path| File.read(path).match?(/^\s+widget :/) }
    assert_empty screen_files.select { |path| File.read(path).match?(/^\s+(chart|table) do/) }
    assert_equal 11, [ api_manifest, users_manifest, jobs_manifest, root_manifest, File.read(File.join(ROOT, "test/dummy/app/admin/stats/manifest.rb")) ].sum { |source| source.scan("RecordingStudioAdmin.register_screen").size }
    assert_equal 5, [ api_manifest, users_manifest, jobs_manifest, root_manifest, File.read(File.join(ROOT, "test/dummy/app/admin/stats/manifest.rb")) ].sum { |source| source.scan("RecordingStudioAdmin.register_section").size }
    assert_includes root_section, 'context.admin_section_path("api")'
    assert_includes root_section, 'context.admin_section_path("users")'
    assert_includes root_section, 'context.admin_section_path("jobs")'
    assert_includes root_section, 'context.admin_section_path("admin_activity_logs")'
    assert_includes api_section, 'widget "api_requests.widgets.api_activity",'
    assert_includes root_section, "view_variant: :compact"
    assert_includes api_section, 'widget "most_common_errors.widgets.error_distribution_chart"'
    assert_includes jobs_section, 'widget "background_jobs.widgets.job_throughput"'
    assert_includes users_manifest, "RecordingStudioAdmin.register_screen(AdminScreens::UserSignIns)"
    assert_includes users_manifest, "RecordingStudioAdmin.register_screen(AdminScreens::UserReviews)"
    assert_includes users_manifest, "RecordingStudioAdmin.register_screen(AdminScreens::UserInvitations)"
    assert_includes users_manifest, "RecordingStudioAdmin.register_screen(AdminScreens::UserGeography)"
    assert_includes users_section, 'widget "user_sign_ins.widgets.sign_in_activity",'
    assert_includes users_section, 'widget "user_reviews.widgets.review_volume",'
    assert_includes users_section, 'link :geography, text: "View user geography"'
    assert_includes users_section, 'widget "user_geography.widgets.activity_geo_map", params: { preset_key: :this_week }'
    assert_includes users_section, 'widget "user_invitations.widgets.recent_invites"'
    assert_includes api_requests_chart, "class ApiRequests"
    assert_includes api_requests_chart, "chart do"
    assert_includes api_requests_table, "class ApiRequests"
    assert_includes api_requests_table, "table do"
    assert_includes api_activity_widget, "class ApiRequests"
    assert_includes api_activity_widget, "widget :api_activity"
    assert_includes review_volume_widget, "class UserReviews"
    assert_includes review_volume_widget, "widget :review_volume"
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
