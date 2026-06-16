# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "__MOUNT_PATH__"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    # Must return the RecordingStudio::Recording that owns the current admin screen context.
    # Example: context.controller.current_root_recording if your app exposes one.
  end
end

# Register screens and sections from config.to_prepare blocks so Rails reloads safely.
# Rails.application.config.to_prepare do
#   RecordingStudioAdmin.register_screen(MyAdminScreen)
#   RecordingStudioAdmin.register_section(MyAdminSection)
# end
