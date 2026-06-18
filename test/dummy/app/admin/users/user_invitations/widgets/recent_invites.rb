# frozen_string_literal: true

module AdminScreens
  class UserInvitations
    widget :recent_invites do
      type :list
      title "Recent invites"
      description "Recently invited users captured by the dummy app."
      subtitle "Latest invitations"
      list_options divider: true, hover: true
      items do |_context|
        UserActivity.where(action: "invited_user").order(created_at: :desc).limit(5).pluck(:email).map do |email|
          {
            icon: :user_plus,
            text: email,
            href: "/users/#{email.parameterize}"
          }
        end
      end
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "user_invitations", preset_key: :this_week)
      end
    end
  end
end