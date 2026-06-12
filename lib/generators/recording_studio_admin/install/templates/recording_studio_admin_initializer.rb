# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = <%= mount_path.inspect %>
  config.authentication_method = :authenticate_user!
  config.authorization_method = :authorize_recording_studio_admin!
  config.current_actor_method = :current_user
end

# Register screens and sections from config.to_prepare blocks so Rails reloads safely.
# Rails.application.config.to_prepare do
#   RecordingStudioAdmin.register_screen(MyAdminScreen)
#   RecordingStudioAdmin.register_section(MyAdminSection)
# end
