# frozen_string_literal: true

module AdminScreens
  class UserGeography
    table do
      filter :search, apply: RecordingStudioAdmin::Filters::Ilike.on(:email)

      column :created_at
      column :email
      column :action
      column :status
      column :country, title: "Country", sortable: false, value: lambda { |row, _context|
        AdminScreens::UserGeography.country_code_for(row.action)
      }

      action :view_user_activity,
             text: "View user activity",
             icon: "user-circle",
              url: ->(row, context) { "#{context.admin_screen_path("user_activity")}?#{ { search: row.email }.to_query }" }

      paginate per_page: 25
    end
  end
end
