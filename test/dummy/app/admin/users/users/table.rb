# frozen_string_literal: true

module AdminScreens
  class Users
    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("email ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :email
      action :view_activity,
             text: "View activity",
             icon: "user-circle",
             url: ->(row, context) { "#{context.admin_screen_path("user_activity")}?#{ { search: row.email }.to_query }" }
      admin_action "users.show", as: :show_user
      admin_action "users.edit", as: :edit_user
      admin_action "users.flag_email"
      paginate per_page: 25
    end
  end
end