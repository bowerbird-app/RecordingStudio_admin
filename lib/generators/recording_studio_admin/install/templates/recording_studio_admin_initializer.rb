# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
end

# Register screens and sections from config.to_prepare blocks so Rails reloads safely.
# Rails.application.config.to_prepare do
#   RecordingStudioAdmin.register_screen(MyAdminScreen)
#   RecordingStudioAdmin.register_section(MyAdminSection)
# end
