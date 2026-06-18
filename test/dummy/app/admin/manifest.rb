# frozen_string_literal: true

module AdminScreens
  RELOADABLE_CONSTANTS = %i[
    Api
    ApiErrors
    ApiSection
    ApiRequests
    BackgroundJobs
    Base
    Jobs
    JobsSection
    MostCommonErrors
    Root
    RootSection
    Stats
    StatsSection
    WorkspaceStats
    UserInvitations
    UserGeography
    UserActivityScreen
    UserReviews
    UserSignIns
    Users
    UsersArea
    UsersResource
    UsersSection
  ].freeze unless const_defined?(:RELOADABLE_CONSTANTS, false)

  DEFINITION_FILES = %w[
    base
    api/api_requests/screen
    api/api_requests/chart
    api/api_requests/table
    api/api_requests/widgets/api_activity
    api/api_requests/widgets/monthly_api_usage
    api/api_errors/screen
    api/api_errors/chart
    api/api_errors/table
    api/api_errors/widgets/recent_failures
    api/most_common_errors/screen
    api/most_common_errors/chart
    api/most_common_errors/table
    api/most_common_errors/widgets/error_distribution_chart
    api/section
    api/manifest
    users/users/screen
    users/users/resource
    users/users/table
    users/user_activity/screen
    users/user_activity/chart
    users/user_activity/table
    users/user_activity/widgets/active_users
    users/user_activity/widgets/review_completion
    users/user_activity/widgets/most_recent_users
    users/user_sign_ins/screen
    users/user_sign_ins/chart
    users/user_sign_ins/table
    users/user_sign_ins/widgets/sign_in_activity
    users/user_reviews/screen
    users/user_reviews/chart
    users/user_reviews/table
    users/user_reviews/widgets/review_volume
    users/user_invitations/screen
    users/user_invitations/chart
    users/user_invitations/table
    users/user_invitations/widgets/recent_invites
    users/user_geography/screen
    users/user_geography/chart
    users/user_geography/table
    users/user_geography/widgets/activity_geo_map
    users/section
    users/manifest
    jobs/background_jobs/screen
    jobs/background_jobs/chart
    jobs/background_jobs/table
    jobs/background_jobs/widgets/job_throughput
    jobs/section
    jobs/manifest
    stats/workspace_stats/screen
    stats/workspace_stats/chart
    stats/workspace_stats/table
    stats/workspace_stats/widgets/total_items
    stats/workspace_stats/widgets/total_pages
    stats/workspace_stats/widgets/total_folders
    stats/workspace_stats/widgets/content_activity
    stats/section
    stats/manifest
    root/section
    root/manifest
  ].freeze unless const_defined?(:DEFINITION_FILES, false)

  def self.load!
    RELOADABLE_CONSTANTS.each do |constant_name|
      remove_const(constant_name) if const_defined?(constant_name, false)
    end

    DEFINITION_FILES.each do |path|
      load Rails.root.join("app/admin/#{path}.rb")
    end
  end
end