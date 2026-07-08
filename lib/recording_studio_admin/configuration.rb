# frozen_string_literal: true

module RecordingStudioAdmin
  class AsyncWidgetConfiguration
    attr_accessor :enabled, :max_concurrent_requests, :retry_count

    def initialize
      @enabled = true
      @max_concurrent_requests = 4
      @retry_count = 1
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end

  class Configuration
    DEFAULT_SURFACE_KEY = "default"
    DEFAULT_ENGINE_LAYOUT = "recording_studio/default_layout"

    attr_accessor :authentication_method, :current_actor_method, :access_recording_method,
                  :access_recording_resolver, :site_admin_recording_resolver, :admin_sections_resolver,
                  :admin_action_auditor, :required_access_role, :default_mount_path, :max_page, :engine_layout
    attr_reader :surfaces, :async_widgets

    def initialize
      @default_mount_path = "/admin"
      @engine_layout = nil
      @authentication_method = :authenticate_user!
      @current_actor_method = :current_user
      @access_recording_method = :recording_studio_admin_access_recording
      @access_recording_resolver = nil
      @site_admin_recording_resolver = nil
      @admin_sections_resolver = nil
      @admin_action_auditor = nil
      @required_access_role = :view
      @max_page = 1_000
      @surfaces = {}
      @async_widgets = AsyncWidgetConfiguration.new
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        if key.to_s == "surfaces"
          merge_surfaces!(value)
          next
        end

        if key.to_s == "async_widgets"
          async_widgets.merge!(value)
          next
        end

        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    def surface(key, **attributes)
      configured_surface = @surfaces[key.to_s] ||= Surface.new(key)
      configured_surface.merge!(attributes) if attributes.any?
      yield configured_surface if block_given?
      configured_surface
    end

    def surface_for(key)
      @surfaces[key.to_s] || default_surface
    end

    def surface_for_request(request)
      matching_surface = @surfaces.values
                                  .select { |configured_surface| configured_surface.matches_request?(request) }
                                  .max_by { |configured_surface| configured_surface.path.to_s.length }
      matching_surface || default_surface
    end

    def default_surface
      Surface.new(
        DEFAULT_SURFACE_KEY,
        path: default_mount_path,
        root_section: :root,
        authentication_method: authentication_method,
        current_actor_method: current_actor_method,
        access_recording_method: access_recording_method,
        access_recording_resolver: access_recording_resolver,
        engine_layout: engine_layout
      )
    end

    private

    def merge_surfaces!(value)
      return unless value.respond_to?(:each)

      value.each do |key, attributes|
        symbolized_attributes = attributes.to_h.transform_keys(&:to_sym)
        surface(key, **symbolized_attributes)
      end
    end
  end
end
