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
        missing_source_lines = tailwind_source_lines.reject { |line| content.include?(line) }
        if missing_source_lines.empty?
          return say("Tailwind already includes RecordingStudioAdmin and FlatPack sources.", :green)
        end

        if content.include?('@import "tailwindcss"')
          inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
            tailwind_injection(missing_source_lines: missing_source_lines)
          end
        else
          say "Could not find @import \"tailwindcss\". Add these Tailwind lines manually:", :yellow
          missing_source_lines.each { |line| say "  #{line}", :yellow }
        end
      end

      def add_importmap_source
        importmap_path = Rails.root.join("config/importmap.rb")
        return show_missing_importmap_notice unless File.exist?(importmap_path)

        content = File.read(importmap_path)
        if content.include?(recording_studio_admin_importmap_pin)
          return say("Importmap already pins RecordingStudioAdmin controllers.",
                     :green)
        end

        append_to_file importmap_path, "\n#{recording_studio_admin_importmap_pin}\n"
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

      def show_missing_importmap_notice
        say "Importmap not detected. Add this line to config/importmap.rb if you use importmap-rails:", :yellow
        say "  #{recording_studio_admin_importmap_pin}", :yellow
      end

      def recording_studio_admin_importmap_pin
        # rubocop:disable Layout/LineLength
        'pin_all_from RecordingStudioAdmin::Engine.root.join("app/javascript/recording_studio_admin/controllers"), under: "controllers/recording_studio_admin", to: "recording_studio_admin/controllers", preload: false'
        # rubocop:enable Layout/LineLength
      end

      def tailwind_source_lines
        [
          '@source "../../vendor/bundle/**/recording_studio_admin/app/views";',
          '@source "../../vendor/bundle/**/recording_studio_admin/app/components";',
          '@source "../../vendor/bundle/**/recording_studio_admin/app/helpers";',
          '@source "../../vendor/bundle/**/recording_studio_admin/app/javascript";',
          '@source "../../vendor/bundle/**/recording_studio_admin/lib";',
          '@source "../../vendor/bundle/**/flat_pack/app/components/**/*.{rb,erb}";',
          '@source "../../vendor/bundle/**/flat_pack/app/helpers/**/*.rb";',
          '@source "../../../../../../usr/local/bundle/**/bundler/gems/flatpack-*/app/components";',
          '@source "../../../../../../usr/local/bundle/**/bundler/gems/flatpack-*/app/helpers";',
          '@source "../../../../../../usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*/app/components";',
          '@source "../../../../../../usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*/app/helpers";'
        ]
      end

      def tailwind_injection(missing_source_lines:)
        [
          "",
          "/* Include RecordingStudioAdmin engine and FlatPack sources.",
          " * Tokens stay in flat_pack/variables. Do not add --color-fp-* or @theme inline. */",
          *missing_source_lines,
          ""
        ].join("\n")
      end
    end
  end
end
