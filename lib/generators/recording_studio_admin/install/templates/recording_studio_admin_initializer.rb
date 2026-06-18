# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "__MOUNT_PATH__"
  config.engine_layout = "application"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    # Must return the RecordingStudio::Recording that owns the current admin screen context.
    # Example: context.controller.current_root_recording if your app exposes one.
  end

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
