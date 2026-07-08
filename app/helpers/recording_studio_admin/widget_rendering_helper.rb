# frozen_string_literal: true

require "digest"

module RecordingStudioAdmin
  module WidgetRenderingHelper
    def recording_studio_widget_presenter(widget, link_policy: nil)
      RecordingStudioAdmin::Widgets::Presenter.new(
        widget,
        link_policy: link_policy || recording_studio_widget_link_policy
      )
    end

    def render_recording_studio_widget(widget, variant: nil, link_policy: nil)
      renderable_widget = variant ? widget.with(view_variant: variant) : widget
      presenter = recording_studio_widget_presenter(renderable_widget, link_policy: link_policy)

      render partial: "recording_studio_admin/shared/widget",
             locals: { widget: renderable_widget, presenter: presenter }
    end

    def render_recording_studio_async_widget_frame(widget, parent:, parent_key:, variant: nil)
      renderable_widget = variant ? widget.with(view_variant: variant) : widget

      render partial: "recording_studio_admin/shared/widget_async_frame",
             locals: {
               widget: renderable_widget,
               parent: parent,
               parent_key: parent_key,
               usage_variant: recording_studio_widget_usage_variant_param(widget)
             }
    end

    def recording_studio_widget_frame_id(parent:, parent_key:, widget:)
      digest = Digest::SHA256.hexdigest([
        parent,
        parent_key,
        widget.key,
        recording_studio_widget_identity_param(widget)
      ].join(":"))[0, 16]
      "recording-studio-admin-widget-#{parent}-#{digest}"
    end

    def recording_studio_widget_frame_src(parent:, parent_key:, widget:, usage_variant: nil)
      query = recording_studio_widget_frame_query(parent: parent, widget: widget, usage_variant: usage_variant)

      if parent.to_sym == :section
        section_widget_path(parent_key, widget.key, query)
      else
        screen_widget_path(parent_key, widget.key, query)
      end
    end

    def recording_studio_widget_usage_variant_param(widget)
      widget.view_variant.presence || "__default__"
    end

    def recording_studio_widget_identity_param(widget)
      recording_studio_widget_usage_index(widget) || recording_studio_widget_usage_variant_param(widget)
    end

    def recording_studio_widget_usage_index(widget)
      widget.metadata[:recording_studio_admin_widget_usage_index] if widget.metadata.respond_to?(:[])
    end

    def recording_studio_async_widgets_data
      async_widgets = RecordingStudioAdmin.configuration.async_widgets
      {
        controller: "recording-studio-admin--async-widgets",
        recording_studio_admin__async_widgets_max_concurrent_value: async_widgets.max_concurrent_requests,
        recording_studio_admin__async_widgets_retry_count_value: async_widgets.retry_count
      }
    end

    def render_recording_studio_widget_body(widget)
      render partial: "recording_studio_admin/shared/widgets/#{widget.type}",
             locals: { widget: widget, presenter: recording_studio_widget_presenter(widget) }
    end

    def render_recording_studio_chart_widget(widget)
      render partial: "recording_studio_admin/shared/widgets/chart",
             locals: { widget: widget, presenter: recording_studio_widget_presenter(widget) }
    end

    private

    def recording_studio_widget_frame_query(parent:, widget:, usage_variant: nil)
      query = request.query_parameters.except(:controller, :action, "controller", "action")
      query[:widget_view_variant] = usage_variant || recording_studio_widget_usage_variant_param(widget)
      usage_index = recording_studio_widget_usage_index(widget)
      query[:widget_usage_index] = usage_index if usage_index
      query[:widget_render_variant] = widget.view_variant if parent.to_sym == :screen && widget.view_variant.present?
      query
    end

    def recording_studio_widget_link_policy
      if respond_to?(:widget_link_url, true)
        ->(url) { widget_link_url(url) }
      else
        ->(url) { RecordingStudioAdmin::UrlSafety.safe_href(url) }
      end
    end
  end
end
