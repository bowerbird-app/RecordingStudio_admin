# frozen_string_literal: true

require "rails/engine"
require "recording_studio_accessible" if defined?(Bundler)
# Query-only: kept/trashed helpers without Trashable engine/importmap/metrics.
require "recording_studio_trashable/query" if defined?(Bundler)

module RecordingStudioAdmin
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAdmin

    initializer "recording_studio_admin.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
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

    initializer "recording_studio_admin.logs" do
      config.to_prepare do
        RecordingStudioAdmin::Engine.install_audit_log_root!
        RecordingStudioAdmin::LogsRegistration.register!
      end
    end

    rake_tasks do
      load File.expand_path("../tasks/recording_studio_admin_audit_logs.rake", __dir__)
    end

    def self.install_audit_log_root!
      klass = RecordingStudioAdmin::LogsRegistration.source_class
      return unless klass
      return if klass.included_modules.include?(RecordingStudioAdmin::AuditLogRoot)

      klass.include RecordingStudioAdmin::AuditLogRoot
    end
  end
end
