# frozen_string_literal: true

require "rails/engine"
require "recording_studio_accessible" if defined?(Bundler)

module RecordingStudioAdmin
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAdmin

    initializer "recording_studio_admin.load_config" do |app|
      next unless app.respond_to?(:config_for)
      next unless app.root.join("config/recording_studio_admin.yml").exist?

      yaml = app.config_for(:recording_studio_admin)
      RecordingStudioAdmin.configuration.merge!(yaml) if yaml.respond_to?(:each)
    end
  end
end
