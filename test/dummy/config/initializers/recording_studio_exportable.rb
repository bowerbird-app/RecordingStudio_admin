# frozen_string_literal: true

if defined?(RecordingStudioExportable)
  RecordingStudioExportable.configure do |config|
    config.current_actor = ->(controller: nil) { controller&.send(:current_user) || Current.actor }

    RecordingStudioExportable.auto_register_exports!(config)

    Rails.application.config.to_prepare do
      RecordingStudioExportable.auto_register_exports!(config)
    end
  end
end