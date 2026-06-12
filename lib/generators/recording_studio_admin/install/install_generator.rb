# frozen_string_literal: true

require "rails/generators"

module RecordingStudioAdmin
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioAdmin engine into your application"

      class_option :mount_path, type: :string, default: "/admin", desc: "Route prefix used when mounting the engine"

      def mount_engine
        route %(mount RecordingStudioAccessible::Engine, at: "#{mount_path}/access")
        route %(mount RecordingStudioAdmin::Engine, at: #{mount_path.inspect})
      end

      def copy_initializer
        template "recording_studio_admin_initializer.rb", "config/initializers/recording_studio_admin.rb"
      end

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)

        content = File.read(tailwind_css_path)
        missing_lines = tailwind_source_lines.reject { |line| content.include?(line) }
        if missing_lines.empty?
          return say("Tailwind already includes RecordingStudioAdmin and FlatPack sources.",
                     :green)
        end

        if content.include?('@import "tailwindcss"')
          inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
            "\n/* Include RecordingStudioAdmin engine and FlatPack sources */\n#{missing_lines.join("\n")}\n"
          end
        else
          say "Could not find @import \"tailwindcss\". Add these Tailwind source lines manually:", :yellow
          missing_lines.each { |line| say "  #{line}", :yellow }
        end
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def mount_path
        value = options[:mount_path].to_s.chomp("/")
        unless value.match?(%r{\A/[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*\z})
          raise ArgumentError, "mount_path must be an absolute route path using letters, numbers, underscores, dashes, and slashes"
        end

        value
      end

      def show_missing_tailwind_notice
        say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
        tailwind_source_lines.each { |line| say "  #{line}", :yellow }
      end

      def tailwind_source_lines
        [
          '@source "../../vendor/bundle/**/recording_studio_admin/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/recording_studio_admin/app/components/**/*.{rb,erb}";',
          '@source "../../vendor/bundle/**/flat_pack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
        ]
      end
    end
  end
end
