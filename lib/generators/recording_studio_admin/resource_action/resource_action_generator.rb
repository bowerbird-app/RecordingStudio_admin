# frozen_string_literal: true

require "rails/generators"

module RecordingStudioAdmin
  module Generators
    class ResourceActionGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :action_name, type: :string

      class_option :model, type: :string, desc: "Active Record model class used by the generated controller action"
      class_option :section, type: :string, desc: "Admin section key that owns this resource"
      class_option :namespace, type: :string, default: "admin", desc: "Host route/controller namespace"
      class_option :screen_key, type: :string, desc: "Admin screen key to redirect back to after the action runs"
      class_option :method, type: :string, default: "post", desc: "HTTP verb for the member action"
      class_option :text, type: :string, desc: "Visible action label. Defaults to a humanized action name"
      class_option :icon, type: :string, desc: "FlatPack icon name for the row action"
      class_option :confirm, type: :string, desc: "Optional confirmation message for mutating actions"
      class_option :destructive, type: :boolean, default: false, desc: "Mark the action as destructive in the dropdown"
      class_option :required_role, type: :string,
                                   desc: "Override the required resource role. Defaults to :admin for non-GET actions"

      def validate_options
        raise ArgumentError, "resource name must be a safe Ruby identifier" unless safe_identifier?(resource_key)
        raise ArgumentError, "action name must be a safe Ruby identifier" unless safe_identifier?(raw_action_name)
        raise ArgumentError, "--namespace must be a safe Ruby identifier" unless safe_identifier?(namespace_name)
        raise ArgumentError, "--section must be a safe admin key" unless safe_key?(section_key)
        raise ArgumentError, "--screen-key must be a safe admin key" unless safe_key?(screen_key)
        raise ArgumentError, "--model is required" if model_class_name.blank?
        raise ArgumentError, "unsupported method: #{http_method}" unless supported_http_methods.include?(http_method)

        return unless required_role_option.present? && !safe_key?(required_role_option)

        raise ArgumentError,
              "--required-role must be a safe role key"
      end

      def update_resource_definition
        ensure_file_exists(resource_definition_path)
        inject_before_anchor(resource_definition_path, resource_anchor, resource_action_block)
      end

      def update_controller
        ensure_file_exists(controller_path)
        inject_before_anchor(controller_path, controller_anchor, controller_action_block)
        inject_before_anchor(controller_path, controller_private_anchor, controller_handler_block)
      end

      def copy_test
        template "test/controllers/resource_action_test.rb", action_test_path
      end

      def add_route
        route <<~RUBY.chomp
          namespace :#{namespace_name} do
            resources :#{route_resource_name}, only: [] do
              #{http_method} :#{normalized_action_name}, on: :member
            end
          end
        RUBY
      end

      def show_table_snippet
        say "Add this admin action to the relevant screen table:", :green
        say %(  admin_action "#{resource_key}.#{normalized_action_name}")
      end

      private

      def model_class_name
        options[:model].to_s.camelize
      end

      def section_key
        (options[:section].presence || resource_key).to_s.underscore
      end

      def namespace_name
        options[:namespace].to_s.underscore
      end

      def screen_key
        (options[:screen_key].presence || resource_key).to_s.underscore
      end

      def resource_key
        file_name.underscore
      end

      def normalized_action_name
        raw_action_name.underscore
      end

      def raw_action_name
        action_name.to_s
      end

      def route_resource_name
        resource_key.pluralize
      end

      def singular_name
        route_resource_name.singularize
      end

      def member_path_helper
        "#{normalized_action_name}_#{namespace_name}_#{singular_name}_path"
      end

      def resource_definition_path
        File.join("app/admin", section_key, resource_key, "resource.rb")
      end

      def controller_path
        File.join("app/controllers", namespace_name, "#{route_resource_name}_controller.rb")
      end

      def action_test_path
        File.join("test/controllers", namespace_name, "#{route_resource_name}_#{normalized_action_name}_test.rb")
      end

      def resource_anchor
        "    def self.record_for(row)"
      end

      def controller_anchor
        "  private"
      end

      def controller_private_anchor
        "  def #{singular_name}_params"
      end

      def action_label
        options[:text].presence || normalized_action_name.humanize
      end

      def icon_name
        options[:icon].presence || default_icon_name
      end

      def default_icon_name
        destructive? ? "trash" : "flag"
      end

      def http_method
        options[:method].to_s.downcase
      end

      def destructive?
        options[:destructive]
      end

      def required_role_option
        options[:required_role].to_s.presence
      end

      def required_role_value
        return required_role_option if required_role_option
        return nil if http_method == "get"

        "admin"
      end

      def confirm_message
        options[:confirm].to_s.presence
      end

      def supported_http_methods
        %w[get post patch put delete]
      end

      def resource_action_block
        lines = []
        lines << ""
        lines << "    action :#{normalized_action_name},"
        lines << %(           text: #{action_label.inspect},)
        lines << %(           icon: #{icon_name.inspect},)
        lines << %(           method: :#{http_method},) unless http_method == "get"
        lines << %(           confirm: #{confirm_message.inspect},) if confirm_message
        lines << "           destructive: true," if destructive?
        lines << %(           url: lambda { |row, context|)
        lines << "             record = record_for(row)"
        lines << %(             context.controller.main_app.#{member_path_helper}(record) if record)
        lines << "           },"
        lines << %(           required_role: :#{required_role_value},) if required_role_value
        lines << "           visible_if: ->(row, _context) { record_for(row).present? }"
        lines << ""
        lines.join("\n")
      end

      def controller_action_block
        <<~RUBY

          def #{normalized_action_name}
            perform_recording_studio_admin_action!(#{resource_key.inspect}, :#{normalized_action_name}, @#{singular_name}) do
              perform_#{resource_key}_#{normalized_action_name}!(@#{singular_name})
            end

            redirect_to recording_studio_admin_context.admin_screen_path(#{screen_key.inspect})
          end
        RUBY
      end

      def controller_handler_block
        <<~RUBY

          def perform_#{resource_key}_#{normalized_action_name}!(record)
            raise NotImplementedError, "Replace perform_#{resource_key}_#{normalized_action_name}! with the app-specific mutation for \#{record.class.name}"
          end
        RUBY
      end

      def ensure_file_exists(path)
        return if File.exist?(File.join(destination_root, path))

        raise ArgumentError,
              "Expected #{path} to exist. Generate the resource form first or create the host files " \
              "before adding a custom action."
      end

      def inject_before_anchor(path, anchor, content)
        absolute_path = File.join(destination_root, path)
        source = File.read(absolute_path)
        return if source.include?(content.strip)

        unless source.include?(anchor)
          raise ArgumentError, "Could not find insertion point #{anchor.inspect} in #{path}"
        end

        insert_into_file path, content, before: anchor
      end

      def safe_identifier?(value)
        value.to_s.match?(/\A[a-z][a-z0-9_]*\z/)
      end

      def safe_key?(value)
        value.to_s.match?(/\A[a-z0-9_]+\z/)
      end
    end
  end
end
