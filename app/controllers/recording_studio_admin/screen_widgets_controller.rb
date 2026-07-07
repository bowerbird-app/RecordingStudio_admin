# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreenWidgetsController < ApplicationController
    def show
      widget = RecordingStudioAdmin::Resolvers::ScreenResolver.resolve_widget(
        key: params[:screen_key],
        widget_key: params[:widget_key],
        view_variant: params[:widget_view_variant],
        usage_index: params[:widget_usage_index],
        context: recording_studio_admin_context
      )
      widget = widget.with(view_variant: render_variant) if render_variant

      render partial: "recording_studio_admin/shared/widget_frame",
             locals: { parent: :screen, parent_key: params[:screen_key], widget: widget }
    end

    private

    def render_variant
      return unless params[:widget_render_variant].to_s == "compact"

      :compact
    end
  end
end
