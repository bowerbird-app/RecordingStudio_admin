# frozen_string_literal: true

module RecordingStudioAdmin
  class Surface
    UNSET = Object.new.freeze

    attr_reader :key
    attr_accessor :authentication_method, :current_actor_method, :access_recording_method,
                  :access_recording_resolver, :engine_layout

    def initialize(key, **attributes)
      @key = key.to_s
      @path = nil
      @root_section_key = nil
      merge!(attributes)
    end

    def merge!(attributes)
      attributes.each do |name, value|
        case name.to_sym
        when :path, :at
          path(value)
        when :root_section, :root_section_key
          root_section(value)
        else
          public_send("#{name}=", value) if respond_to?("#{name}=")
        end
      end
    end

    def path(value = UNSET)
      @path = normalize_path(value) unless value.equal?(UNSET)
      @path
    end

    def root_section(value = UNSET)
      @root_section_key = value.to_s unless value.equal?(UNSET)
      @root_section_key
    end

    def matches_request?(request)
      mount_path = path
      return false if mount_path.to_s.empty?

      request_script_name = request.script_name.to_s.chomp("/")
      return true if request_script_name == mount_path

      request_path = request.path.to_s
      request_path == mount_path || request_path.start_with?("#{mount_path}/")
    end

    private

    def normalize_path(value)
      normalized = value.to_s
      normalized = "/#{normalized}" unless normalized.start_with?("/")
      normalized = normalized.chomp("/")
      normalized.empty? ? "/" : normalized
    end
  end
end