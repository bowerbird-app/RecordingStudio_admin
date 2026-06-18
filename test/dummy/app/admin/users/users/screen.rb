# frozen_string_literal: true

module AdminScreens
  class Users < Base
    key "users"
    icon :user_group
    title "Users"
    subtitle "Manage user accounts"
    query { |_context| User.order(:email) }

    summary do
      label "Total users"
      change_good_when :up
    end
  end
end