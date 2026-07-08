# frozen_string_literal: true

module RecordingStudioAdmin
  class SectionWidgetsController < ApplicationController
    def show
      widget = RecordingStudioAdmin::Resolvers::SectionResolver.resolve_widget(
        key: params[:section_key],
        widget_key: params[:widget_key],
        view_variant: params[:widget_view_variant],
        usage_index: params[:widget_usage_index],
        context: recording_studio_admin_context
      )

      render partial: "recording_studio_admin/shared/widget_frame",
             locals: { parent: :section, parent_key: params[:section_key], widget: widget }
    end
  end
end
