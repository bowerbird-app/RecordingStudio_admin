# frozen_string_literal: true

module RecordingStudioAdmin
  module RecordingStudioAccessibleCompatibility
    def self.install!
      return unless defined?(::RecordingStudioAccessible)
      return if ::RecordingStudioAccessible.const_defined?(:AllowsAccessibleChildren)

      ::RecordingStudioAccessible.const_set(:AllowsAccessibleChildren, allows_accessible_children_module)
    end

    def self.allows_accessible_children_module
      Module.new do
        extend ActiveSupport::Concern

        class_methods do
          def recording_studio_accessible_children(*_children)
            RecordingStudio.configuration.enable_capability(:accessible, on: self)
          end
        end
      end
    end
  end
end
