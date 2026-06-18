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
        route %(recording_studio_admin_for :admin, at: #{mount_path.inspect})
      end

      def copy_initializer
        template "recording_studio_admin_initializer.rb", "config/initializers/recording_studio_admin.rb"
        gsub_file "config/initializers/recording_studio_admin.rb", "__MOUNT_PATH__", mount_path
      end

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)

        content = File.read(tailwind_css_path)
        missing_theme_lines = flatpack_theme_bridge_missing?(content) ? flatpack_theme_bridge_lines : []
        missing_source_lines = tailwind_source_lines.reject { |line| content.include?(line) }
        if missing_theme_lines.empty? && missing_source_lines.empty?
          return say("Tailwind already includes RecordingStudioAdmin and FlatPack sources.",
                     :green)
        end

        if content.include?('@import "tailwindcss"')
          inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
            tailwind_injection(missing_theme_lines: missing_theme_lines, missing_source_lines: missing_source_lines)
          end
        else
          say "Could not find @import \"tailwindcss\". Add these Tailwind lines manually:", :yellow
          (missing_theme_lines + missing_source_lines).each { |line| say "  #{line}", :yellow }
        end
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def mount_path
        value = options[:mount_path].to_s.chomp("/")
        unless value.match?(%r{\A/[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*\z})
          raise ArgumentError,
                "mount_path must be an absolute route path using letters, numbers, underscores, dashes, and slashes"
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

      def flatpack_theme_bridge_lines
        [
          "@theme inline {",
          "  --color-primary: var(--color-primary);",
          "  --color-primary-hover: var(--color-primary-hover);",
          "  --color-primary-text: var(--color-primary-text);",
          "  --color-danger-background-color: var(--color-danger-background-color);",
          "  --color-danger-text-color: var(--color-danger-text-color);",
          "}"
        ]
      end

      def flatpack_theme_bridge_missing?(content)
        !flatpack_theme_bridge_lines.all? { |line| content.include?(line) }
      end

      def tailwind_injection(missing_theme_lines:, missing_source_lines:)
        sections = []
        if missing_theme_lines.any?
          sections << [
            "/* Bridge FlatPack theme tokens into Tailwind semantic utilities */",
            *missing_theme_lines
          ].join("\n")
        end
        if missing_source_lines.any?
          sections << [
            "/* Include RecordingStudioAdmin engine and FlatPack sources */",
            *missing_source_lines
          ].join("\n")
        end

        "\n#{sections.join("\n\n")}\n"
      end
    end
  end
end
