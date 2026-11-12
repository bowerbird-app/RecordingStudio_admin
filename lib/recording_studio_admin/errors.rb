# frozen_string_literal: true

module RecordingStudioAdmin
  class Error < StandardError; end
  class DefinitionNotFound < Error; end
  class AuthorizationFailed < Error; end
  class RegistryConflict < Error; end
  class InvalidDefinition < Error; end

  class ScopeLimitExceeded < Error
    attr_reader :limit

    def initialize(limit)
      @limit = limit
      super("Too many items under this spot. The limit is #{limit}. Open a smaller one.")
    end
  end
end
