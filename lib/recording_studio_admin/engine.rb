# frozen_string_literal: true

require "rails/engine"
require "recording_studio_accessible" if defined?(Bundler)

module RecordingStudioAdmin
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAdmin

    initializer "recording_studio_admin.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/javascript")
      end
    end

    initializer "recording_studio_admin.load_config" do |app|
      next unless app.respond_to?(:config_for)
      next unless app.root.join("config/recording_studio_admin.yml").exist?

      yaml = app.config_for(:recording_studio_admin)
      RecordingStudioAdmin.configuration.merge!(yaml) if yaml.respond_to?(:each)
    end

    initializer "recording_studio_admin.routing" do
      ActionDispatch::Routing::Mapper.include RecordingStudioAdmin::Routing
    end

    initializer "recording_studio_admin.built_in_admin_activity_logs" do |app|
      app.config.to_prepare do
        RecordingStudioAdmin.register_screen(RecordingStudioAdmin::AdminActivityLogsScreen)
        RecordingStudioAdmin.register_section(RecordingStudioAdmin::AdminActivityLogsSection)
        RecordingStudioAdmin.register_widget(RecordingStudioAdmin::AdminActivityLogsActivityOverview)
      end
    end
  end
end
