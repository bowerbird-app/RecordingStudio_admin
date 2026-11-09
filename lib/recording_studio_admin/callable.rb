# frozen_string_literal: true

module RecordingStudioAdmin
  module Callable
    module_function

    def resolve(callable, context)
      arity = callable.arity
      case arity
      when 0 then callable.call
      when 1, -1 then callable.call(context)
      else callable.call(context, context.controller)
      end
    end
  end
end
