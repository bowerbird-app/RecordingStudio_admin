# frozen_string_literal: true

module RecordingStudioAdmin
  class Error < StandardError; end
  class DefinitionNotFound < Error; end
  class RegistryConflict < Error; end
end
