# frozen_string_literal: true

module RecordingStudioAdmin
  class Configuration
    attr_accessor :authentication_method, :authorization_method, :current_actor_method, :default_mount_path, :max_page

    def initialize
      @default_mount_path = "/admin"
      @authentication_method = :authenticate_user!
      @authorization_method = :authorize_recording_studio_admin!
      @current_actor_method = :current_user
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
