# frozen_string_literal: true

module AdminScreens
  class UserActivityScreen
    widget :most_recent_users do
      type :list
      title "Most recent users"
      description "The five most recent users seen by the dummy app."
      subtitle "Latest five users"
      list_options divider: true, hover: true
      items do |_context|
        UserActivity.order(created_at: :desc).limit(5).pluck(:email).map do |email|
          {
            icon: :user_circle,
            text: email,
            href: "/users/#{email.parameterize}"
          }
        end
      end
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "user_activity", preset_key: :this_week)
      end
    end
  end
end