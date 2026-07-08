# frozen_string_literal: true

module AdminScreens
  class UsersResource < RecordingStudioAdmin::Resource
    key "users"
    section "users"
    icon :user_group
    title "Manage users"
    subtitle "Edit user account details"
    blast_radius :site

    action :show,
           text: "Show",
           icon: "eye",
           url: lambda { |row, context|
             user = user_for(row)
             context.controller.main_app.admin_user_path(user) if user
           },
           visible_if: ->(row, _context) { user_for(row).present? }

    action :edit,
           text: "Edit user",
           icon: "pencil-square",
           url: lambda { |row, context|
             user = user_for(row)
             context.controller.main_app.edit_admin_user_path(user) if user
           },
           required_role: :admin,
           visible_if: ->(row, _context) { user_for(row).present? }

    action :flag_email,
           text: "Flag email",
           icon: "flag",
           method: :post,
           confirm: ->(row, _context) { "Flag #{row.email}?" },
           url: lambda { |row, context|
             user = user_for(row)
             context.controller.main_app.flag_email_admin_user_path(user) if user
           },
           visible_if: ->(row, _context) { user_for(row).present? }

    def self.user_for(row)
      return row if row.is_a?(User)
      return unless row.respond_to?(:email)

      User.find_by(email: row.email)
    end
  end
end
