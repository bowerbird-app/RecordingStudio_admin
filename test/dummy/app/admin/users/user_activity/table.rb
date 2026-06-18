# frozen_string_literal: true

module AdminScreens
  class UserActivityScreen
    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("email ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :email
      column :action
      column :status
      action :view_sign_ins,
             text: "View sign-ins",
             icon: "arrow-right-end-on-rectangle",
             url: ->(row, context) { "#{context.admin_screen_path("user_sign_ins")}?#{ { search: row.email }.to_query }" }
      action :review_queue,
             text: "Review queue",
             icon: "clipboard-document-check",
             url: ->(row, context) { "#{context.admin_screen_path("user_reviews")}?#{ { search: row.email }.to_query }" },
             visible_if: ->(row, _context) { row.status == "review" }
      action :delete_activity,
             text: "Delete activity",
             icon: "trash",
             url: ->(row, _context) { "/admin/user_activities/#{row.id}" },
             method: :delete,
             confirm: ->(row, _context) { "Delete activity for #{row.email}?" },
             destructive: true
      paginate per_page: 25
    end
  end
end