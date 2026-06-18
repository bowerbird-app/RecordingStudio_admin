# frozen_string_literal: true

module AdminScreens
  class UserSignIns
    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("email ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :email
      column :status
      action :view_activity,
        text: "View activity",
        icon: "user-circle",
        url: ->(row, context) { "#{context.admin_screen_path("user_activity")}?#{ { search: row.email }.to_query }" }
      action :review_queue,
        text: "Review queue",
        icon: "clipboard-document-check",
        url: ->(row, context) { "#{context.admin_screen_path("user_reviews")}?#{ { search: row.email }.to_query }" },
        visible_if: ->(row, _context) { row.status == "review" }
      action :delete_sign_in,
        text: "Delete sign-in",
        icon: "trash",
        url: ->(row, _context) { "/admin/user_activities/#{row.id}" },
        method: :delete,
        confirm: ->(row, _context) { "Delete sign-in activity for #{row.email}?" },
        destructive: true
      paginate per_page: 25
    end
  end
end