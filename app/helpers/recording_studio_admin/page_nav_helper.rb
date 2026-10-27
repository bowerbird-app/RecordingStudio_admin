# frozen_string_literal: true

module RecordingStudioAdmin
  module PageNavHelper
    def recording_studio_admin_page_heading(title:, anchor:, subtitle: nil)
      content_for(:title, title) if title.present?
      content_for(:subtitle, subtitle) if subtitle.present?
      flat_pack_page_nav(
        round: true,
        style: :default,
        anchor_href: anchor,
        anchor_tooltip: t("recording_studio.admin.navigation.close", default: "Close"),
        back_tooltip: t("recording_studio.admin.navigation.go_back", default: "Go back")
      )
      nil
    end

    def recording_studio_admin_register_page_actions(actions, overflow_after: 3)
      Array(actions).each_with_index do |action, index|
        register_page_nav(
          action.text,
          preserve_anchor_url(action.url),
          role: recording_studio_admin_page_nav_role(action.style),
          overflow: index >= overflow_after
        )
      end
      nil
    end

    def recording_studio_admin_page_nav_role(style)
      case style.to_s
      when "primary" then :primary
      when "danger", "destructive" then :destructive
      else :secondary
      end
    end
  end
end
