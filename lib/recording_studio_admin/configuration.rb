# frozen_string_literal: true

module RecordingStudioAdmin
  class Configuration
    attr_accessor :authentication_method, :current_actor_method, :access_recording_method,
                  :access_recording_resolver, :required_access_role, :default_mount_path, :max_page

    def initialize
      @default_mount_path = "/admin"
      @authentication_method = :authenticate_user!
      @current_actor_method = :current_user
      @access_recording_method = :recording_studio_admin_access_recording
      @access_recording_resolver = nil
      @required_access_role = :view
      @max_page = 1_000
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end
end
