# frozen_string_literal: true

module AdminScreens
  class Library < Base
    key "library"
    icon :folder
    title "Library"
    subtitle "Folders and pages under this workspace"
    blast_radius :recording
    filter_presentation :inline

    scopeable recordable_types: %w[Folder Page]
    filter :folder, type: :within, label: "Folder", recordable_type: "Folder",
           name: ->(recording) { recording.recordable.name }
    filter :recordable_type, label: "Kind"
    filter :person, label: "Who", apply: lambda { |relation, value, _context|
      Library.narrow_by_name(relation, value)
    }

    query { |context| context.scoped_recordings }

    summary do
      label "Items"
      change_good_when :up
    end

    class << self
      def narrow_by_name(relation, value)
        term = value.to_s.strip
        return relation if term.empty?

        like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        relation.where(name_match_sql, folder: "Folder", page: "Page", like: like)
      end

      def name_match_sql
        <<~SQL.squish
          (
            recording_studio_recordings.recordable_type = :folder
            AND recording_studio_recordings.recordable_id IN (
              SELECT id FROM folders WHERE name ILIKE :like
            )
          ) OR (
            recording_studio_recordings.recordable_type = :page
            AND recording_studio_recordings.recordable_id IN (
              SELECT id FROM pages WHERE title ILIKE :like
            )
          )
        SQL
      end
    end
  end
end
