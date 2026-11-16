# frozen_string_literal: true

# Site-wide screens (blast_radius :site) resolve only when the current access
# recording is this kept root and RecordingStudioAccessible.admin? allows the
# actor. The callable may take an optional context: keyword. A missing root
# fails closed.
RecordingStudioAccessible.configure do |config|
  config.admin_root_resolver = lambda do |context: nil|
    # Return the kept RecordingStudio::Recording for the admin root.
    # Example:
    #   admin_root = AdminRoot.find_by(name: "Admin")
    #   next unless admin_root
    #   RecordingStudio::Recording.kept.find_by(recordable: admin_root)
  end
end

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "__MOUNT_PATH__"
  # Leave layout unset so Recording Studio core's Default Layout applies.
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user

  # Progressive widget loading keeps the page shell fast and lets widgets load
  # through engine-owned endpoints with bounded browser concurrency. It is on by
  # default; uncomment the next line only if you need synchronous widget renders.
  # config.async_widgets.enabled = false
  # config.async_widgets.max_concurrent_requests = 4
  # config.async_widgets.retry_count = 1

  # Mask these attributes in admin audit metadata, in addition to filter_parameters.
  # config.audit_filtered_attributes = %w[badge_code]

  config.access_recording_resolver = lambda do |context|
    # Must return the RecordingStudio::Recording that owns the current admin screen context.
    # The mounted admin usually uses the admin root:
    #   RecordingStudioAccessible.admin_root(context: context)
  end

  # Admin audit logs register with RecordingStudioLogs as an unpartitioned,
  # indefinite raw log. A finite window is not cleaned by RS_Logs without
  # summaries, so leave this as :indefinite.
  # config.logs_retention = :indefinite

  # Add per-route admin surfaces when different URL entrypoints should resolve
  # different access recordings or layouts.
  # config.surface :stats do |surface|
  #   surface.access_recording_resolver = ->(context) { context.controller.current_user_recording }
  #   surface.root_section :page_views
  # end
end

# Keep admin definitions in app/admin capability folders, then register them from
# config.to_prepare blocks so Rails reloads safely.
# If your app/admin files are manifest-loaded instead of Zeitwerk-named, add
# `Rails.autoloaders.main.ignore(root.join("app/admin"))` in config/application.rb.
# Rails.application.config.to_prepare do
#   load Rails.root.join("app/admin/manifest.rb")
#   AdminScreens.load!
#   AdminScreens.register!
# end
