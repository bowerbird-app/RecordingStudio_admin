# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreenFilterOptionsController < ApplicationController
    def index
      definition = authorized_screen
      filter = within_filter(definition)
      raise DefinitionNotFound, "Filter #{params[:filter_key].inspect} is not available" unless filter

      render json: {
        items: recording_studio_admin_context.within_catalog_for(filter).search(query: params[:q], page: params[:page])
      }
    end

    private

    def authorized_screen
      definition = registered_screen
      context = recording_studio_admin_context
      authorize_screen!(definition, context)
      ensure_screen_available!(definition, context)
      definition
    end

    def registered_screen
      key = params[:key].to_s
      definition = RecordingStudioAdmin.screen_for(key)
      return definition if definition

      raise DefinitionNotFound, "Screen #{key.inspect} is not registered"
    end

    def authorize_screen!(definition, context)
      RecordingStudioAdmin::Authorization.authorize!(context)
      RecordingStudioAdmin::BlastRadius.authorize!(
        definition,
        context: context,
        label: "Screen #{definition.key.inspect}"
      )
    end

    def ensure_screen_available!(definition, context)
      return if enabled?(definition, context) && visible?(definition, context)

      key = definition.key.inspect
      message = enabled?(definition, context) ? "is not visible" : "is not enabled for this root"
      raise DefinitionNotFound, "Screen #{key} #{message}"
    end

    def within_filter(definition)
      filters = Array(definition.filters) + Array(definition.table_value&.filters)
      filters.find { |entry| entry.type.to_sym == :within && entry.key.to_s == params[:filter_key].to_s }
    end

    def enabled?(definition, context)
      RecordingStudioAdmin.screen_enabled?(
        key: definition.key,
        recording: context.access_recording,
        context: context
      )
    end

    def visible?(definition, context)
      return true unless definition.visible_if

      definition.visible_if.call(context)
    end
  end
end
