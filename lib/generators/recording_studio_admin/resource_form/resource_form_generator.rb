# frozen_string_literal: true

require "rails/generators"

module RecordingStudioAdmin
  module Generators
    class ResourceFormGenerator < Rails::Generators::NamedBase
      FieldSpec = Struct.new(:name, :type, keyword_init: true) do
        def label
          name.to_s.humanize
        end

        def email?
          type.to_s == "email" || name.to_s.match?(/email/)
        end

        def select?
          %w[select enum].include?(type.to_s)
        end

        def boolean?
          %w[boolean bool checkbox].include?(type.to_s)
        end
      end

      source_root File.expand_path("templates", __dir__)

      desc "Generates host-owned RecordingStudioAdmin resource show/edit/update scaffolding"

      class_option :model, type: :string, desc: "Active Record model class to manage, for example User"
      class_option :section, type: :string, desc: "Admin section key that owns this resource"
      class_option :namespace, type: :string, default: "admin", desc: "Host route/controller namespace"
      class_option :screen_key, type: :string, desc: "Admin screen key to redirect back to after updates"
      class_option :fields, type: :array, default: [], desc: "Editable fields, for example email:string role:select"
      class_option :actions, type: :array, default: %w[show edit update], desc: "Host REST actions to route"

      def validate_options
        raise ArgumentError, "--model is required" if model_class_name.blank?
        raise ArgumentError, "--section is required" if section_key.blank?
        raise ArgumentError, "--fields requires at least one field" if fields.empty?
        raise ArgumentError, "--namespace must be a safe Ruby identifier" unless safe_identifier?(namespace_name)
        raise ArgumentError, "resource name must be a safe Ruby identifier" unless safe_identifier?(resource_key)
        raise ArgumentError, "--section must be a safe admin key" unless safe_key?(section_key)
        raise ArgumentError, "--screen-key must be a safe admin key" unless safe_key?(screen_key)

        unknown_actions = route_actions - %w[show edit update]
        raise ArgumentError, "unsupported actions: #{unknown_actions.join(', ')}" if unknown_actions.any?

        return unless route_actions.include?("update") && !route_actions.include?("edit")

        raise ArgumentError,
              "update requires edit authorization"
      end

      def copy_resource_definition
        template "app/admin/resource.rb", "app/admin/#{section_key}/#{resource_key}/resource.rb"
      end

      def copy_controller
        template "app/controllers/resource_controller.rb",
                 "app/controllers/#{namespace_name}/#{controller_file_name}_controller.rb"
      end

      def copy_views
        template "app/views/resource/show.html.erb", "app/views/#{namespace_name}/#{controller_file_name}/show.html.erb"
        template "app/views/resource/edit.html.erb", "app/views/#{namespace_name}/#{controller_file_name}/edit.html.erb"
      end

      def add_route
        route <<~RUBY.chomp
          namespace :#{namespace_name} do
            resources :#{route_resource_name}, only: %i[#{route_actions.join(' ')}]
          end
        RUBY
      end

      def show_table_snippet
        say "Add these admin actions to the relevant screen table:", :green
        say %(  admin_action "#{resource_key}.show", as: :show_#{singular_name}) if route_actions.include?("show")
        say %(  admin_action "#{resource_key}.edit", as: :edit_#{singular_name}) if route_actions.include?("edit")
      end

      private

      def model_class_name
        options[:model].to_s.camelize
      end

      def model_param_key
        model_class_name.underscore
      end

      def section_key
        options[:section].to_s.underscore
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

      def resource_class_name
        "#{resource_key.camelize}Resource"
      end

      def controller_file_name
        route_resource_name
      end

      def controller_class_name
        "#{namespace_name.camelize}::#{controller_file_name.camelize}Controller"
      end

      def route_resource_name
        resource_key.pluralize
      end

      def singular_name
        route_resource_name.singularize
      end

      def instance_name
        "@#{singular_name}"
      end

      def route_actions
        Array(options[:actions]).map { |action| action.to_s.underscore }.presence || %w[show edit update]
      end

      def fields
        @fields ||= Array(options[:fields]).map { |field| parse_field(field) }
      end

      def field_names
        fields.map(&:name)
      end

      def display_field
        fields.find(&:email?) || fields.first
      end

      def parse_field(value)
        name, type = value.to_s.split(":", 2)
        name = name.to_s.underscore
        raise ArgumentError, "field names must be safe Ruby identifiers" unless safe_identifier?(name)

        FieldSpec.new(name: name, type: (type.presence || "string").underscore)
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
