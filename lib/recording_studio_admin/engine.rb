# frozen_string_literal: true

require "rails/engine"
require "recording_studio_accessible" if defined?(Bundler)

module RecordingStudioAdmin
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAdmin

    initializer "recording_studio_admin.load_config" do |app|
      yaml = app.config_for(:recording_studio_admin) if app.respond_to?(:config_for)
      RecordingStudioAdmin.configuration.merge!(yaml) if yaml.respond_to?(:each)
    rescue StandardError
      nil
    end
  end
end
