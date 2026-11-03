# frozen_string_literal: true

if defined?(RecordingStudioExportable)
  RecordingStudioExportable.configure do |config|
    config.current_actor = ->(controller: nil) { Current.actor || controller&.current_user }

    RecordingStudioExportable.auto_register_exports!(config)

    Rails.application.config.to_prepare do
      RecordingStudioExportable.auto_register_exports!(config)
    end
  end
end
