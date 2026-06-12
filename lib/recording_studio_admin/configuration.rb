# frozen_string_literal: true

module RecordingStudioAdmin
  class Configuration
    attr_accessor :default_mount_path

    def initialize
      @default_mount_path = "/admin"
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
