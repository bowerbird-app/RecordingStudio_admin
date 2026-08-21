# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreenWidgetsController < ApplicationController
    def show
      return redirect_to_screen if recording_studio_admin_page_visit?

      render partial: "recording_studio_admin/shared/widget_frame",
             locals: { parent: :screen, parent_key: params[:screen_key], widget: resolved_widget }
    end

    private

    def resolved_widget
      widget = RecordingStudioAdmin::Resolvers::ScreenResolver.resolve_widget(
        key: params[:screen_key],
        widget_key: params[:widget_key],
        view_variant: params[:widget_view_variant],
        usage_index: params[:widget_usage_index],
        context: recording_studio_admin_context
      )

      render_variant ? widget.with(view_variant: render_variant) : widget
    end

    def redirect_to_screen
      redirect_to_recording_studio_admin_page(recording_studio_admin_context.admin_screen_path(params[:screen_key]))
    end

    def render_variant
      return unless params[:widget_render_variant].to_s == "compact"

      :compact
    end
  end
end
